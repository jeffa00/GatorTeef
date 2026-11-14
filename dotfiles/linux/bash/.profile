# Load once per shell so a private override that sources this file (or
# itself) cannot recurse. Keep this POSIX sh: display managers read .profile
# with /bin/sh. Not exported on purpose.
if [ -n "${_GATORTEEF_PROFILE_LOADED:-}" ]; then
  return
fi
_GATORTEEF_PROFILE_LOADED=1

export PATH="$HOME/.local/bin:$HOME/bin:$PATH"

if [ -n "$BASH_VERSION" ] && [ -f "$HOME/.bashrc" ]; then
  . "$HOME/.bashrc"
fi

if [ -f "$HOME/.config/dev-environment/private/dotfiles/linux/bash/.profile" ]; then
  . "$HOME/.config/dev-environment/private/dotfiles/linux/bash/.profile"
fi
