#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PUBLIC_TMUX_DIR="$REPO_ROOT/tmux"
TMUXINATOR_CONFIG_ROOT=""
TMPDIR_PATH=""
ATTACH_TARGET=""
COMMAND="${1:-}"
shift || true

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/private-overrides.sh"

# Same private repo resolution as setup: PRIVATE_REPO_ROOT, then
# DEV_ENV_PRIVATE_REPO, then the ../dev-environment-private sibling.
PRIVATE_REPO_ROOT="$(dev_env_private_repo_root)"
PRIVATE_TMUX_DIR="$PRIVATE_REPO_ROOT/tmux"

ENTRY_TEMPLATES=()
ENTRY_NAMES=()

trim() {
  local value
  value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s\n' "$value"
}

strip_quotes() {
  local value
  value="$1"
  value="$(trim "$value")"
  case "$value" in
    \"*\") value="${value#\"}"; value="${value%\"}" ;;
    \'*\') value="${value#\'}"; value="${value%\'}" ;;
  esac
  printf '%s\n' "$value"
}

cleanup() {
  if [ -n "$TMPDIR_PATH" ] && [ -d "$TMPDIR_PATH" ]; then
    rm -rf "$TMPDIR_PATH"
  fi
}

trap cleanup EXIT

# Ignores a private repo that is really a copy of this public repo.
private_repo_present() {
  private_repo_available
}

defaults_file_path() {
  private_repo_present || return 0
  if [ -f "$PRIVATE_TMUX_DIR/defaults.yaml" ]; then
    printf '%s\n' "$PRIVATE_TMUX_DIR/defaults.yaml"
  elif [ -f "$PRIVATE_TMUX_DIR/defaults.yml" ]; then
    printf '%s\n' "$PRIVATE_TMUX_DIR/defaults.yml"
  fi
}

list_definition_names() {
  local subdir
  subdir="$1"

  {
    find "$PUBLIC_TMUX_DIR/$subdir" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) -exec basename {} \; 2>/dev/null
    if private_repo_present; then
      find "$PRIVATE_TMUX_DIR/$subdir" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) -exec basename {} \; 2>/dev/null
    fi
  } | sed -E 's/\.(yml|yaml)$//' | sort -u
}

resolve_definition_file() {
  local subdir
  local name
  subdir="$1"
  name="$2"

  if private_repo_present; then
    if [ -f "$PRIVATE_TMUX_DIR/$subdir/$name.yml" ]; then
      printf '%s\n' "$PRIVATE_TMUX_DIR/$subdir/$name.yml"
      return
    fi
    if [ -f "$PRIVATE_TMUX_DIR/$subdir/$name.yaml" ]; then
      printf '%s\n' "$PRIVATE_TMUX_DIR/$subdir/$name.yaml"
      return
    fi
  fi

  if [ -f "$PUBLIC_TMUX_DIR/$subdir/$name.yml" ]; then
    printf '%s\n' "$PUBLIC_TMUX_DIR/$subdir/$name.yml"
    return
  fi
  if [ -f "$PUBLIC_TMUX_DIR/$subdir/$name.yaml" ]; then
    printf '%s\n' "$PUBLIC_TMUX_DIR/$subdir/$name.yaml"
    return
  fi
}

session_template_file() {
  resolve_definition_file "sessions" "$1"
}

workspace_file() {
  resolve_definition_file "workspaces" "$1"
}

entry_exists() {
  local name
  local existing
  name="$1"
  for existing in "${ENTRY_NAMES[@]:-}"; do
    if [ "$existing" = "$name" ]; then
      return 0
    fi
  done
  return 1
}

append_entry() {
  local template
  local name
  template="$1"
  name="$2"

  if entry_exists "$name"; then
    warn "Skipping duplicate session name: $name"
    return
  fi

  ENTRY_TEMPLATES+=("$template")
  ENTRY_NAMES+=("$name")
}

parse_template_list_file() {
  local file_path
  local line
  local template
  local name
  local value

  file_path="$1"
  template=""
  name=""

  while IFS= read -r line || [ -n "$line" ]; do
    line="$(trim "$line")"
    [ -n "$line" ] || continue
    case "$line" in
      \#*)
        continue
        ;;
      attach:*)
        value="${line#attach:}"
        ATTACH_TARGET="$(strip_quotes "$value")"
        ;;
      -\ template:*)
        if [ -n "$template" ]; then
          append_entry "$template" "${name:-$template}"
        fi
        value="${line#- template:}"
        template="$(strip_quotes "$value")"
        name=""
        ;;
      template:*)
        if [ -n "$template" ]; then
          append_entry "$template" "${name:-$template}"
        fi
        value="${line#template:}"
        template="$(strip_quotes "$value")"
        name=""
        ;;
      name:*)
        value="${line#name:}"
        name="$(strip_quotes "$value")"
        ;;
    esac
  done < "$file_path"

  if [ -n "$template" ]; then
    append_entry "$template" "${name:-$template}"
  fi
}

parse_template_arg() {
  local arg
  local template
  local name
  local workspace_path
  local session_path

  arg="$1"
  if [[ "$arg" == *:* ]]; then
    template="${arg%%:*}"
    name="${arg#*:}"
  else
    template="$arg"
    name="$arg"
  fi

  workspace_path="$(workspace_file "$template" || true)"
  if [ -n "$workspace_path" ]; then
    if [ "$name" != "$template" ]; then
      die "Workspace arguments do not support a custom session name override: $arg"
    fi
    parse_template_list_file "$workspace_path"
    return
  fi

  session_path="$(session_template_file "$template" || true)"
  [ -n "$session_path" ] || die "Unknown tmux session template or workspace: $template"
  append_entry "$template" "$name"
}

prepare_tmuxinator_config() {
  local file
  local base_name

  TMPDIR_PATH="$(mktemp -d)"
  TMUXINATOR_CONFIG_ROOT="$TMPDIR_PATH/tmuxinator"
  mkdir -p "$TMUXINATOR_CONFIG_ROOT"

  if [ -d "$PUBLIC_TMUX_DIR/sessions" ]; then
    for file in "$PUBLIC_TMUX_DIR"/sessions/*; do
      [ -f "$file" ] || continue
      base_name="$(basename "$file")"
      ln -s "$file" "$TMUXINATOR_CONFIG_ROOT/$base_name"
    done
  fi

  if private_repo_present && [ -d "$PRIVATE_TMUX_DIR/sessions" ]; then
    for file in "$PRIVATE_TMUX_DIR"/sessions/*; do
      [ -f "$file" ] || continue
      base_name="$(basename "$file")"
      rm -f "$TMUXINATOR_CONFIG_ROOT/$base_name"
      ln -s "$file" "$TMUXINATOR_CONFIG_ROOT/$base_name"
    done
  fi
}

ensure_backend() {
  command_exists tmux || die "tmux is required."
  command_exists tmuxinator || die "tmuxinator is not installed. Run 'bash scripts/setup.sh --install-tmuxinator' first."
}

session_exists() {
  tmux has-session -t "$1" >/dev/null 2>&1
}

attach_to_session() {
  local target
  target="$1"

  if [ -n "${TMUX:-}" ]; then
    tmux switch-client -t "$target"
  else
    tmux attach-session -t "$target"
  fi
}

start_entries() {
  local index
  local template
  local session_name

  ensure_backend
  prepare_tmuxinator_config

  if [ "${#ENTRY_TEMPLATES[@]}" -eq 0 ]; then
    die "No tmux templates were selected."
  fi

  if [ -z "$ATTACH_TARGET" ]; then
    ATTACH_TARGET="${ENTRY_NAMES[0]}"
  fi

  for index in "${!ENTRY_TEMPLATES[@]}"; do
    template="${ENTRY_TEMPLATES[$index]}"
    session_name="${ENTRY_NAMES[$index]}"

    if session_exists "$session_name"; then
      log "tmux session already exists: $session_name"
      continue
    fi

    log "Starting tmux template '$template' as session '$session_name'"
    TMUXINATOR_CONFIG="$TMUXINATOR_CONFIG_ROOT" \
      DEV_ENV_PROJECT_ROOT="$REPO_ROOT" \
      DEV_ENV_PRIVATE_REPO_ROOT="$PRIVATE_REPO_ROOT" \
      tmuxinator start "$template" -n "$session_name"
  done

  attach_to_session "$ATTACH_TARGET"
}

show_list() {
  local defaults_path

  printf 'Sessions:\n'
  list_definition_names "sessions" | sed 's/^/  - /'
  printf '\nWorkspaces:\n'
  list_definition_names "workspaces" | sed 's/^/  - /'

  defaults_path="$(defaults_file_path || true)"
  if [ -n "$defaults_path" ]; then
    printf '\nDefaults file:\n  - %s\n' "$defaults_path"
  else
    printf '\nDefaults file:\n  - not configured\n'
  fi
}

load_defaults() {
  local file_path
  file_path="$(defaults_file_path || true)"
  [ -n "$file_path" ] || die "No templates were specified and no defaults file was found. Configure $PRIVATE_TMUX_DIR/defaults.yaml or pass template names explicitly."
  parse_template_list_file "$file_path"
}

case "$COMMAND" in
  "" )
    load_defaults
    start_entries
    ;;
  help|--help|-h)
    cat <<EOF
Usage:
  scripts/tmux-session.sh list
  scripts/tmux-session.sh start <name> [name...]
  scripts/tmux-session.sh <name> [name...]
  scripts/tmux-session.sh

Arguments can be session template names, workspace names, or session-template overrides in the form template:session-name.
Running with no arguments loads defaults from the sibling private overlay repo when configured.
EOF
    ;;
  list)
    show_list
    ;;
  start)
    [ "$#" -gt 0 ] || die "Provide at least one template or workspace name."
    while [ "$#" -gt 0 ]; do
      parse_template_arg "$1"
      shift
    done
    start_entries
    ;;
  *)
    parse_template_arg "$COMMAND"
    while [ "$#" -gt 0 ]; do
      parse_template_arg "$1"
      shift
    done
    start_entries
    ;;
esac
