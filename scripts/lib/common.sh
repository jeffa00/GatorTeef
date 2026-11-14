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
  case "${ID:-} ${ID_LIKE:-}" in
    ubuntu\ *|*\ ubuntu|*\ ubuntu\ *)
      ;;
    *)
      die "This setup currently supports Ubuntu and Ubuntu-based distros (such as Pop!_OS) on Linux and WSL. Detected: ${PRETTY_NAME:-${ID:-unknown}}."
      ;;
  esac
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

  if [ "${DRY_RUN:-0}" -eq 1 ]; then
    log "mkdir -p $font_dir"
    log "curl -fsSL -o <temp>/JetBrainsMono.zip https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
    log "unzip -o <temp>/JetBrainsMono.zip -d $font_dir"
    log "fc-cache -f $HOME/.local/share/fonts"
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

# Neovim on Linux/WSL comes from the official release tarball instead of apt:
# the pinned nvim-treesitter (main branch) needs Neovim 0.12+, and Ubuntu's
# apt package lags behind. Keep this in step with the macOS Homebrew version.
# Digests are the sha256 values GitHub publishes for each release asset.
NEOVIM_VERSION="0.12.4"

neovim_linux_asset() {
  case "$(uname -m)" in
    x86_64|amd64)
      printf '%s %s\n' "nvim-linux-x86_64" "012bf3fcac5ade43914df3f174668bf64d05e049a4f032a388c027b1ebd78628"
      ;;
    aarch64|arm64)
      printf '%s %s\n' "nvim-linux-arm64" "ceb7e88c6b681f0515d135dcdfad54f5eb4373b25ce6172197cd9a69c758063f"
      ;;
    *)
      die "No Neovim release tarball for architecture: $(uname -m)"
      ;;
  esac
}

install_neovim_linux() {
  local asset_name
  local asset_sha256
  local install_root
  local url
  local temp_dir
  local tarball

  read -r asset_name asset_sha256 < <(neovim_linux_asset)
  install_root="$HOME/.local/opt/nvim-$NEOVIM_VERSION"
  url="https://github.com/neovim/neovim/releases/download/v$NEOVIM_VERSION/$asset_name.tar.gz"

  if [ -x "$install_root/bin/nvim" ]; then
    log "Neovim $NEOVIM_VERSION already installed in $install_root"
  elif [ "${DRY_RUN:-0}" -eq 1 ]; then
    log "curl -fsSL -o <temp>/$asset_name.tar.gz $url"
    log "verify sha256 $asset_sha256"
    log "tar -xzf <temp>/$asset_name.tar.gz and move to $install_root"
    log "ln -s $install_root/bin/nvim $HOME/.local/bin/nvim"
    return
  else
    temp_dir="$(mktemp -d)"
    trap 'rm -rf "$temp_dir"' RETURN
    tarball="$temp_dir/$asset_name.tar.gz"

    run mkdir -p "$HOME/.local/opt"
    run curl -fsSL -o "$tarball" "$url"
    log "Verifying sha256 of $asset_name.tar.gz"
    # die exits without firing the RETURN trap, so clean up explicitly first.
    if ! printf '%s  %s\n' "$asset_sha256" "$tarball" | sha256sum -c --quiet -; then
      rm -rf "$temp_dir"
      die "Checksum mismatch for $url"
    fi
    run tar -xzf "$tarball" -C "$temp_dir"
    if [ ! -x "$temp_dir/$asset_name/bin/nvim" ]; then
      rm -rf "$temp_dir"
      die "Unexpected Neovim tarball layout: $asset_name/bin/nvim missing"
    fi
    run mv "$temp_dir/$asset_name" "$install_root"
    run rm -rf "$temp_dir"
    trap - RETURN
  fi

  link_file "$install_root/bin/nvim" "$HOME/.local/bin/nvim"
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
