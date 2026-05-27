#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/linking.sh"
source "$SCRIPT_DIR/lib/private-overrides.sh"

[ "$(detect_platform)" = "wsl" ] || die "setup-wsl.sh must be run inside WSL"
require_apt
require_ubuntu

apply_windows_terminal_template() {
  local windows_local_appdata
  local windows_settings_path
  local destination_path

  windows_local_appdata="$(cmd.exe /c "echo %LOCALAPPDATA%" 2>/dev/null | tr -d '\r')"
  [ -n "$windows_local_appdata" ] || die "Unable to determine Windows LOCALAPPDATA from WSL."

  windows_settings_path="$windows_local_appdata\\Packages\\Microsoft.WindowsTerminal_8wekyb3d8bbwe\\LocalState\\settings.json"
  destination_path="$(wslpath "$windows_settings_path")"

  ensure_dir "$(dirname "$destination_path")"
  link_file "$REPO_ROOT/dotfiles/wsl/windows-terminal/settings.json" "$destination_path"
}

log "Installing Ubuntu packages for WSL"
run sudo apt-get update
run xargs -a "$REPO_ROOT/packages/apt.txt" sudo apt-get install -y
install_starship

if [ "${INSTALL_TMUXINATOR:-0}" -eq 1 ]; then
  log "Installing optional tmux workspace backend"
  run sudo apt-get install -y tmuxinator
fi

if [ "${INSTALL_DOTNET:-0}" -eq 1 ]; then
  log "Installing optional .NET SDK"
  install_dotnet_ubuntu
fi

install_nerd_font_ubuntu

log "Applying managed config"
ensure_dir "$HOME/.config"
ensure_dir "$HOME/.local/bin"
scaffold_private_overrides_for_platform "wsl"
sync_optional_private_link \
  "dotfiles/shared/tmux/tmux.conf" \
  "$(managed_private_override_path "dotfiles/shared/tmux/tmux.conf")"
sync_optional_private_link \
  "dotfiles/shared/nvim/theme.lua" \
  "$(managed_private_override_path "dotfiles/shared/nvim/theme.lua")"
sync_optional_private_link \
  "dotfiles/linux/bash/.profile" \
  "$(managed_private_override_path "dotfiles/linux/bash/.profile")"
sync_optional_private_link \
  "dotfiles/linux/bash/.bashrc" \
  "$(managed_private_override_path "dotfiles/linux/bash/.bashrc")"
STARSHIP_CONFIG_PATH="$(generated_config_path "starship.toml")"
generate_starship_config
link_file "$REPO_ROOT/dotfiles/linux/bash/.profile" "$HOME/.profile"
link_file "$REPO_ROOT/dotfiles/linux/bash/.bashrc" "$HOME/.bashrc"
link_file "$REPO_ROOT/scripts/te" "$HOME/.local/bin/te"
link_generated_file "$STARSHIP_CONFIG_PATH" "$HOME/.config/starship.toml"
link_file "$REPO_ROOT/dotfiles/shared/tmux/tmux.conf" "$HOME/.tmux.conf"
link_dir "$REPO_ROOT/dotfiles/shared/nvim" "$HOME/.config/nvim"

if [ "${INSTALL_DOTNET:-0}" -eq 1 ] || [ "${ENABLE_DOTNET_NVIM:-0}" -eq 1 ]; then
  link_dotnet_shell_env
fi

if [ "${ENABLE_DOTNET_NVIM:-0}" -eq 1 ]; then
  require_dotnet
  link_dotnet_nvim_marker
fi

if [ "${APPLY_WINDOWS_TERMINAL:-0}" -eq 1 ]; then
  log "Applying Windows Terminal settings template"
  apply_windows_terminal_template
else
  warn "Windows Terminal settings were not applied. Re-run with --apply-windows-terminal to link the tracked template."
fi

log "Validating installed tools"
validate_command tmux
if [ "${INSTALL_TMUXINATOR:-0}" -eq 1 ]; then
  validate_command tmuxinator
fi
if [ "${INSTALL_DOTNET:-0}" -eq 1 ]; then
  validate_command dotnet
fi
if [ "${ENABLE_DOTNET_NVIM:-0}" -eq 1 ] && [ "${INSTALL_DOTNET:-0}" -eq 0 ]; then
  validate_command dotnet
fi
validate_command nvim
validate_command starship
