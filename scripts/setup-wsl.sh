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
  local source_path
  local source_windows_path
  local current_target
  local escaped_windows_settings_path
  local escaped_source_windows_path

  backup_windows_terminal_settings() {
    local backup_path
    local backup_windows_path
    local escaped_backup_windows_path

    backup_path="${destination_path}.backup.$(timestamp)"
    backup_windows_path="$(wslpath -w "$backup_path" 2>/dev/null | tr -d '\r')"

    [ -n "$backup_windows_path" ] || die "Unable to convert Windows Terminal backup path for Windows access."

    escaped_backup_windows_path="${backup_windows_path//\'/\'\'}"

    if [ "${DRY_RUN:-0}" -eq 1 ]; then
      log "powershell.exe -NoProfile -Command Move-Item -LiteralPath '$windows_settings_path' -Destination '$backup_windows_path' -Force"
      return
    fi

    log "Backing up Windows Terminal settings to $backup_windows_path"
    powershell.exe -NoProfile -Command "Move-Item -LiteralPath '$escaped_windows_settings_path' -Destination '$escaped_backup_windows_path' -Force -ErrorAction Stop" >/dev/null
  }

  windows_local_appdata="$(cmd.exe /c "echo %LOCALAPPDATA%" 2>/dev/null | tr -d '\r')"
  [ -n "$windows_local_appdata" ] || die "Unable to determine Windows LOCALAPPDATA from WSL."

  windows_settings_path="$windows_local_appdata\\Packages\\Microsoft.WindowsTerminal_8wekyb3d8bbwe\\LocalState\\settings.json"
  destination_path="$(wslpath "$windows_settings_path")"
  source_path="$REPO_ROOT/dotfiles/wsl/windows-terminal/settings.json"
  source_windows_path="$(wslpath -w "$source_path" 2>/dev/null | tr -d '\r')"

  [ -n "$source_windows_path" ] || die "Unable to convert Windows Terminal template path for Windows access."

  ensure_dir "$(dirname "$destination_path")"

  escaped_windows_settings_path="${windows_settings_path//\'/\'\'}"
  escaped_source_windows_path="${source_windows_path//\'/\'\'}"

  current_target="$(
    powershell.exe -NoProfile -Command "\$item = Get-Item -LiteralPath '$escaped_windows_settings_path' -ErrorAction SilentlyContinue; if (\$null -ne \$item -and \$item.LinkType -eq 'SymbolicLink') { [Console]::Write(\$item.Target) }" 2>/dev/null \
      | tr -d '\r'
  )"

  if [ -n "$current_target" ] && [ "$current_target" = "$source_windows_path" ]; then
    log "Already linked: $windows_settings_path"
    return
  fi

  if [ -e "$destination_path" ] || [ -L "$destination_path" ]; then
    backup_windows_terminal_settings
  fi

  if [ "${DRY_RUN:-0}" -eq 1 ]; then
    log "powershell.exe -NoProfile -Command New-Item -ItemType SymbolicLink -Path '$windows_settings_path' -Target '$source_windows_path'"
    return
  fi

  log "Creating Windows Terminal symlink"
  powershell.exe -NoProfile -Command "New-Item -ItemType SymbolicLink -Path '$escaped_windows_settings_path' -Target '$escaped_source_windows_path' -ErrorAction Stop | Out-Null" >/dev/null
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
