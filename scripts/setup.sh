#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DRY_RUN=0
APPLY_WINDOWS_TERMINAL=0
INSTALL_TMUXINATOR=0
INSTALL_DOTNET=0
ENABLE_DOTNET_NVIM=0

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/private-overrides.sh"

print_help() {
  cat <<'EOF'
Usage:
  bash scripts/setup.sh [options]

Options:
  -h, --help                Show this help text
  -n, --dry-run             Preview actions without making changes
      --apply-windows-terminal
                            Apply the tracked Windows Terminal settings in WSL
      --install-tmuxinator  Install the optional tmux workspace backend
      --install-dotnet      Install the optional .NET SDK layer
      --enable-dotnet-nvim  Enable the optional Neovim .NET layer

Examples:
  bash scripts/setup.sh
  bash scripts/setup.sh --dry-run
  bash scripts/setup.sh --install-dotnet --enable-dotnet-nvim
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      print_help
      exit 0
      ;;
    -n|--dry-run)
      DRY_RUN=1
      ;;
    --apply-windows-terminal)
      APPLY_WINDOWS_TERMINAL=1
      ;;
    --install-tmuxinator)
      INSTALL_TMUXINATOR=1
      ;;
    --install-dotnet)
      INSTALL_DOTNET=1
      ;;
    --enable-dotnet-nvim)
      ENABLE_DOTNET_NVIM=1
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
  shift
done

export DRY_RUN
export APPLY_WINDOWS_TERMINAL
export INSTALL_TMUXINATOR
export INSTALL_DOTNET
export ENABLE_DOTNET_NVIM
export REPO_ROOT

warn_if_private_repo_is_public_clone

case "$(detect_platform)" in
  macos)
    bash "$SCRIPT_DIR/setup-macos.sh"
    ;;
  linux)
    bash "$SCRIPT_DIR/setup-linux.sh"
    ;;
  wsl)
    bash "$SCRIPT_DIR/setup-wsl.sh"
    ;;
  *)
    die "Unsupported platform"
    ;;
esac
