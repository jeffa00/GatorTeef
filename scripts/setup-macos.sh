#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/linking.sh"
source "$SCRIPT_DIR/lib/private-overrides.sh"

[ "$(detect_platform)" = "macos" ] || die "setup-macos.sh must be run on macOS"

manage_ghostty_macos() {
  local managed_source
  local legacy_path

  managed_source="$1"

  ensure_dir "$HOME/.config/ghostty"
  link_generated_file "$managed_source" "$HOME/.config/ghostty/config.ghostty"

  while IFS= read -r legacy_path; do
    if [ "$legacy_path" != "$HOME/.config/ghostty/config.ghostty" ] && { [ -e "$legacy_path" ] || [ -L "$legacy_path" ]; }; then
      backup_path "$legacy_path"
    fi
  done < <(legacy_ghostty_config_paths)
}

log "Installing macOS packages"
require_brew
run brew update
if brew bundle check --file "$REPO_ROOT/Brewfile" >/dev/null 2>&1; then
  log "Brewfile dependencies are already satisfied"
else
  run brew bundle install --file "$REPO_ROOT/Brewfile"
fi

if [ "${INSTALL_TMUXINATOR:-0}" -eq 1 ]; then
  if command_exists rbenv || command_exists rvm; then
    warn "tmuxinator via Homebrew can interfere with rbenv/rvm GEM_HOME. Consider a gem-based install if you manage Ruby versions locally."
  fi
  log "Installing optional tmux workspace backend"
  run brew install tmuxinator
fi

if [ "${INSTALL_DOTNET:-0}" -eq 1 ]; then
  log "Installing optional .NET SDK"
  install_dotnet_macos
fi

log "Applying managed config"
ensure_dir "$HOME/.config"
ensure_dir "$HOME/.local/bin"
scaffold_private_overrides_for_platform "macos"
sync_optional_private_link \
  "dotfiles/shared/tmux/tmux.conf" \
  "$(managed_private_override_path "dotfiles/shared/tmux/tmux.conf")"
sync_optional_private_link \
  "dotfiles/shared/nvim/theme.lua" \
  "$(managed_private_override_path "dotfiles/shared/nvim/theme.lua")"
sync_optional_private_link \
  "dotfiles/macos/zsh/.zprofile" \
  "$(managed_private_override_path "dotfiles/macos/zsh/.zprofile")"
sync_optional_private_link \
  "dotfiles/macos/zsh/.zshrc" \
  "$(managed_private_override_path "dotfiles/macos/zsh/.zshrc")"
STARSHIP_CONFIG_PATH="$(generated_config_path "starship.toml")"
GHOSTTY_CONFIG_PATH="$(generated_config_path "ghostty-macos.config.ghostty")"
generate_starship_config
generate_ghostty_config "macos"
link_file "$REPO_ROOT/dotfiles/macos/zsh/.zprofile" "$HOME/.zprofile"
link_file "$REPO_ROOT/dotfiles/macos/zsh/.zshrc" "$HOME/.zshrc"
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

manage_ghostty_macos "$GHOSTTY_CONFIG_PATH"

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
validate_command ghostty
validate_command starship
