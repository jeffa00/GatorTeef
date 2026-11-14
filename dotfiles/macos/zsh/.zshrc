# Load once per shell so a private override that sources this file (or
# itself) cannot recurse. Not exported on purpose.
if [ -n "${_GATORTEEF_ZSHRC_LOADED:-}" ]; then
  return
fi
_GATORTEEF_ZSHRC_LOADED=1

export EDITOR="nvim"
export VISUAL="$EDITOR"
export PAGER="less -FRX"

HISTFILE="${ZDOTDIR:-$HOME}/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000

setopt AUTO_CD
setopt HIST_IGNORE_DUPS
setopt HIST_REDUCE_BLANKS
setopt SHARE_HISTORY

autoload -Uz compinit
compinit -d "${ZDOTDIR:-$HOME}/.zcompdump"

zstyle ':completion:*' menu select
bindkey -e

alias l='ls -CF'
alias la='ls -A'
alias ll='ls -lah'

if [ -f "$HOME/.config/dev-environment/dotnet.sh" ]; then
  . "$HOME/.config/dev-environment/dotnet.sh"
fi

if [ -f "$HOME/.config/dev-environment/private/dotfiles/macos/zsh/.zshrc" ]; then
  . "$HOME/.config/dev-environment/private/dotfiles/macos/zsh/.zshrc"
fi

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi
