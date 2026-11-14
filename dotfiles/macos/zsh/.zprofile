# Load once per shell so a private override that sources this file (or
# itself) cannot recurse. Not exported on purpose.
if [ -n "${_GATORTEEF_ZPROFILE_LOADED:-}" ]; then
  return
fi
_GATORTEEF_ZPROFILE_LOADED=1

export PATH="$HOME/.local/bin:$HOME/bin:$PATH"

if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

if [ -f "$HOME/.config/dev-environment/private/dotfiles/macos/zsh/.zprofile" ]; then
  . "$HOME/.config/dev-environment/private/dotfiles/macos/zsh/.zprofile"
fi
