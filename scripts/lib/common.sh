#!/usr/bin/env bash

log() {
  printf '==> %s\n' "$*"
}

warn() {
  printf 'Warning: %s\n' "$*" >&2
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

run() {
  log "$*"
  if [ "${DRY_RUN:-0}" -eq 0 ]; then
    "$@"
  fi
}

run_shell() {
  log "$*"
  if [ "${DRY_RUN:-0}" -eq 0 ]; then
    bash -lc "$*"
  fi
}

detect_platform() {
  case "$(uname -s)" in
    Darwin)
      printf 'macos\n'
      ;;
    Linux)
      if grep -qi microsoft /proc/version 2>/dev/null || [ -n "${WSL_DISTRO_NAME:-}" ]; then
        printf 'wsl\n'
      else
        printf 'linux\n'
      fi
      ;;
    *)
      printf 'unsupported\n'
      ;;
  esac
}

require_brew() {
  command_exists brew || die "Homebrew is required. Install it from https://brew.sh/"
}

require_apt() {
  command_exists apt-get || die "apt-get is required for Ubuntu/WSL installs."
}

require_ubuntu() {
  [ -f /etc/os-release ] || die "Cannot determine Linux distribution."
  . /etc/os-release
  [ "${ID:-}" = "ubuntu" ] || die "This setup currently supports Ubuntu for Linux/WSL."
}

ubuntu_version() {
  [ -f /etc/os-release ] || die "Cannot determine Ubuntu version."
  . /etc/os-release
  [ -n "${VERSION_ID:-}" ] || die "Cannot determine Ubuntu version."
  printf '%s\n' "$VERSION_ID"
}

repo_root_from_script_dir() {
  local script_dir
  script_dir="$1"
  cd "$script_dir/.." && pwd
}

legacy_ghostty_config_paths() {
  printf '%s\n' \
    "$HOME/.config/ghostty/config" \
    "$HOME/Library/Application Support/com.mitchellh.ghostty/config" \
    "$HOME/Library/Application Support/com.mitchellh.ghostty/config.ghostty"
}

install_nerd_font_ubuntu() {
  local font_dir
  local temp_dir
  local zip_path

  font_dir="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"

  if [ -d "$font_dir" ] && find "$font_dir" -name 'JetBrainsMonoNerdFont-*.ttf' -print -quit | grep -q .; then
    log "JetBrains Mono Nerd Font already installed for this user"
    return
  fi

  temp_dir="$(mktemp -d)"
  zip_path="$temp_dir/JetBrainsMono.zip"

  run mkdir -p "$font_dir"
  run curl -fsSL -o "$zip_path" "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
  run unzip -o "$zip_path" -d "$font_dir"
  run fc-cache -f "$HOME/.local/share/fonts"
  run rm -rf "$temp_dir"
}

install_ghostty_ubuntu() {
  if dpkg -s ghostty >/dev/null 2>&1; then
    log "ghostty already installed"
    return
  fi

  run sudo add-apt-repository -y ppa:mkasberg/ghostty-ubuntu
  run sudo apt-get update
  run sudo apt-get install -y ghostty
}

install_starship() {
  local temp_dir
  local install_script

  if [ -x "$HOME/.local/bin/starship" ]; then
    export PATH="$HOME/.local/bin:$PATH"
    log "starship already installed in $HOME/.local/bin"
    return
  fi

  if command_exists starship; then
    log "starship already installed"
    return
  fi

  if [ "${DRY_RUN:-0}" -eq 1 ]; then
    log "mkdir -p $HOME/.local/bin"
    log "curl -fsSL -o <temp>/starship-install.sh https://starship.rs/install.sh"
    log "sh <temp>/starship-install.sh --yes --bin-dir $HOME/.local/bin"
    return
  fi

  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' RETURN
  install_script="$temp_dir/starship-install.sh"

  run mkdir -p "$HOME/.local/bin"
  run curl -fsSL -o "$install_script" https://starship.rs/install.sh
  run sh "$install_script" --yes --bin-dir "$HOME/.local/bin"
  run rm -rf "$temp_dir"
  trap - RETURN

  export PATH="$HOME/.local/bin:$PATH"
}

install_dotnet_macos() {
  if brew list --formula dotnet >/dev/null 2>&1; then
    log ".NET SDK already installed through Homebrew"
    return
  fi

  run brew install dotnet
}

install_dotnet_ubuntu() {
  local version_id
  local version_major

  version_id="$(ubuntu_version)"
  version_major="${version_id%%.*}"

  if dpkg -s dotnet-sdk-10.0 >/dev/null 2>&1; then
    log ".NET 10 SDK already installed"
    return
  fi

  case "$version_id" in
    22.04)
      run sudo add-apt-repository -y ppa:dotnet/backports
      run sudo apt-get update
      ;;
    *)
      if [ "$version_major" -lt 24 ]; then
        die "The opt-in .NET install path currently supports Ubuntu 22.04 and Ubuntu 24.04 or newer."
      fi
      ;;
  esac

  run sudo apt-get install -y dotnet-sdk-10.0
}

require_dotnet() {
  command_exists dotnet || die ".NET SDK is required. Run 'bash scripts/setup.sh --install-dotnet' first, or install dotnet before enabling the Neovim .NET layer."
}

link_dotnet_shell_env() {
  ensure_dir "$HOME/.config/dev-environment"
  link_file "$REPO_ROOT/dotfiles/shared/dev-environment/dotnet.sh" "$HOME/.config/dev-environment/dotnet.sh"
}

link_dotnet_nvim_marker() {
  ensure_dir "$HOME/.config/dev-environment"
  link_file "$REPO_ROOT/dotfiles/shared/dev-environment/enable-dotnet-nvim" "$HOME/.config/dev-environment/enable-dotnet-nvim"
}

validate_command() {
  local command_name
  local version_output
  command_name="$1"

  if command_exists "$command_name"; then
    case "$command_name" in
      tmux)
        version_output="$("$command_name" -V 2>/dev/null | head -n 1)"
        ;;
      *)
        version_output="$("$command_name" --version 2>/dev/null | head -n 1)"
        ;;
    esac

    if [ -n "$version_output" ]; then
      log "$version_output"
    else
      warn "Could not determine version for $command_name"
    fi
  else
    warn "$command_name is not available on PATH"
  fi
}
