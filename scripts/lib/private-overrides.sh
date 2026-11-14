#!/usr/bin/env bash

dev_env_private_repo_root() {
  if [ -n "${PRIVATE_REPO_ROOT:-}" ]; then
    printf '%s\n' "$PRIVATE_REPO_ROOT"
  elif [ -n "${DEV_ENV_PRIVATE_REPO:-}" ]; then
    printf '%s\n' "$DEV_ENV_PRIVATE_REPO"
  else
    printf '%s\n' "$REPO_ROOT/../dev-environment-private"
  fi
}

# True when the configured private repo is actually a clone or copy of this
# public repo (for example the old public "dev-environment" repo cloned under
# the private name). Treating it as an overlay makes every public file its
# own override, which loops forever in shells and tmux.
private_repo_is_public_clone() {
  local private_root
  local public_root_commit

  private_root="$(dev_env_private_repo_root)"
  [ -d "$private_root" ] || return 1

  if [ -f "$private_root/scripts/te" ] && [ -f "$private_root/scripts/setup.sh" ]; then
    return 0
  fi

  if command_exists git && [ -e "$private_root/.git" ] && [ -e "$REPO_ROOT/.git" ]; then
    while IFS= read -r public_root_commit; do
      [ -n "$public_root_commit" ] || continue
      if git -C "$private_root" cat-file -e "${public_root_commit}^{commit}" 2>/dev/null; then
        return 0
      fi
    done < <(git -C "$REPO_ROOT" rev-list --max-parents=0 HEAD 2>/dev/null)
  fi

  return 1
}

warn_if_private_repo_is_public_clone() {
  if private_repo_is_public_clone; then
    warn "The private repo at $(dev_env_private_repo_root) is a copy of this public repo, not a private overlay. Ignoring it: no private overrides will be linked. Move it aside and clone your real private overlay repo there, or set PRIVATE_REPO_ROOT."
  fi
}

private_repo_available() {
  [ -d "$(dev_env_private_repo_root)" ] && ! private_repo_is_public_clone
}

private_override_file() {
  local relative_path
  local candidate

  relative_path="$1"
  private_repo_available || return 0
  candidate="$(dev_env_private_repo_root)/$relative_path"

  if [ -f "$candidate" ]; then
    printf '%s\n' "$candidate"
  fi
}

write_private_override_scaffold_if_missing() {
  local destination_path
  local content

  destination_path="$1"
  content="$2"

  if [ -e "$destination_path" ] || [ -L "$destination_path" ]; then
    log "Private override scaffold already exists: $destination_path"
    return
  fi

  ensure_dir "$(dirname "$destination_path")"

  if [ "${DRY_RUN:-0}" -eq 1 ]; then
    log "Would create private override scaffold: $destination_path"
    return
  fi

  printf '%s' "$content" > "$destination_path"
  log "Created private override scaffold: $destination_path"
}

copy_private_override_scaffold_if_missing() {
  local source_path
  local destination_path

  source_path="$1"
  destination_path="$2"

  if [ -e "$destination_path" ] || [ -L "$destination_path" ]; then
    log "Private override scaffold already exists: $destination_path"
    return
  fi

  ensure_dir "$(dirname "$destination_path")"

  if [ "${DRY_RUN:-0}" -eq 1 ]; then
    log "Would create private override scaffold from baseline: $destination_path"
    return
  fi

  cp "$source_path" "$destination_path"
  log "Created private override scaffold from baseline: $destination_path"
}

scaffold_private_override_file() {
  local relative_path
  local content

  relative_path="$1"
  content="$2"

  write_private_override_scaffold_if_missing \
    "$(dev_env_private_repo_root)/$relative_path" \
    "$content"
}

scaffold_private_override_from_public_file() {
  local relative_path

  relative_path="$1"

  copy_private_override_scaffold_if_missing \
    "$REPO_ROOT/$relative_path" \
    "$(dev_env_private_repo_root)/$relative_path"
}

scaffold_shared_private_overrides() {
  scaffold_private_override_file \
    "dotfiles/shared/tmux/tmux.conf" \
    $'# Private tmux overrides loaded after the public baseline.\n'

  scaffold_private_override_file \
    "dotfiles/shared/nvim/theme.lua" \
    $'-- Private Neovim theme selection loaded from the shared baseline.\n-- Define the colorscheme to use for each OS appearance.\nreturn {\n  light = "catppuccin-latte",\n  dark = "catppuccin-mocha",\n}\n'

  scaffold_private_override_from_public_file \
    "dotfiles/shared/shell/starship.toml"
}

scaffold_macos_private_overrides() {
  scaffold_private_override_file \
    "dotfiles/macos/zsh/.zprofile" \
    $'# Private macOS zprofile overrides loaded near the end of the public baseline.\n'

  scaffold_private_override_file \
    "dotfiles/macos/zsh/.zshrc" \
    $'# Private macOS zshrc overrides loaded near the end of the public baseline.\n'

  scaffold_private_override_file \
    "dotfiles/macos/ghostty/config.ghostty" \
    $'# Private macOS Ghostty overrides appended after the public baseline.\n'
}

scaffold_linux_private_overrides() {
  scaffold_private_override_file \
    "dotfiles/linux/bash/.profile" \
    $'# Private Linux profile overrides loaded near the end of the public baseline.\n'

  scaffold_private_override_file \
    "dotfiles/linux/bash/.bashrc" \
    $'# Private Linux bashrc overrides loaded near the end of the public baseline.\n'

  scaffold_private_override_file \
    "dotfiles/linux/ghostty/config.ghostty" \
    $'# Private Linux Ghostty overrides appended after the public baseline.\n'
}

scaffold_wsl_private_overrides() {
  scaffold_private_override_file \
    "dotfiles/linux/bash/.profile" \
    $'# Private WSL profile overrides loaded near the end of the public baseline.\n'

  scaffold_private_override_file \
    "dotfiles/linux/bash/.bashrc" \
    $'# Private WSL bashrc overrides loaded near the end of the public baseline.\n'
}

scaffold_private_overrides_for_platform() {
  local platform

  platform="$1"

  if ! private_repo_available; then
    log "No usable private repo; skipping private override scaffolding"
    return
  fi

  scaffold_shared_private_overrides

  case "$platform" in
    macos)
      scaffold_macos_private_overrides
      ;;
    linux)
      scaffold_linux_private_overrides
      ;;
    wsl)
      scaffold_wsl_private_overrides
      ;;
    *)
      warn "Unknown platform for private override scaffolding: $platform"
      ;;
  esac
}

managed_dev_environment_root() {
  printf '%s\n' "$HOME/.config/dev-environment"
}

managed_private_override_path() {
  local relative_path
  relative_path="$1"
  printf '%s/private/%s\n' "$(managed_dev_environment_root)" "$relative_path"
}

generated_config_path() {
  local filename
  filename="$1"
  printf '%s/generated/%s\n' "$(managed_dev_environment_root)" "$filename"
}

remove_managed_optional_file() {
  local destination_path
  destination_path="$1"

  if [ -L "$destination_path" ] || [ -f "$destination_path" ]; then
    run rm -f "$destination_path"
  fi
}

# True when a private override references its own managed path outside a
# comment. The public baseline already loads that path, so a file that
# sources it again loops forever (bash segfaults, tmux hits its nesting limit).
private_override_references_itself() {
  local private_relative_path
  local private_source

  private_relative_path="$1"
  private_source="$2"

  grep -v '^[[:space:]]*#' "$private_source" \
    | grep -Fq "dev-environment/private/$private_relative_path"
}

sync_optional_private_link() {
  local private_relative_path
  local managed_destination
  local private_source

  private_relative_path="$1"
  managed_destination="$2"
  private_source="$(private_override_file "$private_relative_path" || true)"

  if [ -n "$private_source" ] && private_override_references_itself "$private_relative_path" "$private_source"; then
    warn "Not linking private override $private_source: it references its own managed path (dev-environment/private/$private_relative_path), which the public baseline already loads, so it would loop forever. Remove that reference and re-run setup."
    remove_managed_optional_file "$managed_destination"
    return
  fi

  if [ -n "$private_source" ]; then
    link_file "$private_source" "$managed_destination"
  else
    remove_managed_optional_file "$managed_destination"
  fi
}

is_generated_dev_environment_file() {
  local file_path
  file_path="$1"

  [ -f "$file_path" ] || return 1
  head -n 1 "$file_path" | grep -Fq "Managed by dev-environment"
}

write_generated_file() {
  local destination_path
  local temporary_path

  destination_path="$1"
  temporary_path="$2"

  ensure_dir "$(dirname "$destination_path")"

  if [ -d "$destination_path" ]; then
    rm -f "$temporary_path"
    die "Refusing to replace directory with generated file: $destination_path"
  fi

  if [ -f "$destination_path" ] && cmp -s "$temporary_path" "$destination_path"; then
    log "Already up to date: $destination_path"
    rm -f "$temporary_path"
    return
  fi

  if [ -L "$destination_path" ]; then
    backup_path "$destination_path"
  elif [ -e "$destination_path" ] && ! is_generated_dev_environment_file "$destination_path"; then
    backup_path "$destination_path"
  fi

  if [ "${DRY_RUN:-0}" -eq 1 ]; then
    log "Would write generated file: $destination_path"
    rm -f "$temporary_path"
    return
  fi

  mv "$temporary_path" "$destination_path"
  log "Wrote generated file: $destination_path"
}

write_generated_header() {
  local public_source
  local private_source

  public_source="$1"
  private_source="$2"

  printf '# Managed by dev-environment. Do not edit this file directly.\n'
  printf '# Public source: %s\n' "$public_source"
  if [ -n "$private_source" ]; then
    printf '# Private source: %s\n' "$private_source"
  fi
  printf '\n'
}

generate_starship_config() {
  local public_source
  local private_source
  local destination_path
  local temporary_path

  public_source="$REPO_ROOT/dotfiles/shared/shell/starship.toml"
  private_source="$(private_override_file "dotfiles/shared/shell/starship.toml" || true)"
  destination_path="$(generated_config_path "starship.toml")"
  temporary_path="$(mktemp)"

  write_generated_header "$public_source" "$private_source" > "$temporary_path"

  if [ -n "$private_source" ]; then
    printf '# Starship private overrides use full replacement because TOML does not support safe duplicate-key merging.\n\n' >> "$temporary_path"
    cat "$private_source" >> "$temporary_path"
  else
    cat "$public_source" >> "$temporary_path"
  fi
  write_generated_file "$destination_path" "$temporary_path"
}

generate_ghostty_config() {
  local platform
  local public_source
  local private_source
  local destination_path
  local temporary_path

  platform="$1"
  public_source="$REPO_ROOT/dotfiles/$platform/ghostty/config.ghostty"
  private_source="$(private_override_file "dotfiles/$platform/ghostty/config.ghostty" || true)"
  destination_path="$(generated_config_path "ghostty-$platform.config.ghostty")"
  temporary_path="$(mktemp)"

  write_generated_header "$public_source" "$private_source" > "$temporary_path"
  cat "$public_source" >> "$temporary_path"

  if [ -n "$private_source" ]; then
    printf '\n# Private overrides appended from %s\n\n' "$private_source" >> "$temporary_path"
    cat "$private_source" >> "$temporary_path"
  fi
  write_generated_file "$destination_path" "$temporary_path"
}
