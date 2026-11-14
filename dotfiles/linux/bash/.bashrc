case $- in
  *i*) ;;
  *) return ;;
esac

# Load once per shell so a private override that sources this file (or
# itself) cannot recurse until bash crashes. Not exported on purpose: child
# shells should load their own copy.
if [ -n "${_GATORTEEF_BASHRC_LOADED:-}" ]; then
  return
fi
_GATORTEEF_BASHRC_LOADED=1

export EDITOR="nvim"
export VISUAL="$EDITOR"
export PAGER="less -FRX"

HISTFILE="$HOME/.bash_history"
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth:erasedups

shopt -s autocd
shopt -s checkwinsize
shopt -s histappend

alias l='ls -CF'
alias la='ls -A'
alias ll='ls -lah'

if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
  alias fd='fdfind'
fi

if [ -f "$HOME/.config/dev-environment/dotnet.sh" ]; then
  . "$HOME/.config/dev-environment/dotnet.sh"
fi

if [ -f "$HOME/.config/dev-environment/private/dotfiles/linux/bash/.bashrc" ]; then
  . "$HOME/.config/dev-environment/private/dotfiles/linux/bash/.bashrc"
fi

# Some desktop sessions (e.g. GNOME on Ubuntu) start terminals without running
# ~/.profile, so make sure user-installed tools like starship are on PATH.
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init bash)"
fi
