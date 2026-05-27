# Repository Layout

This repository is split into **managed content** and **orchestration**:

- `dotfiles/` owns the tracked config that should exist on a machine.
- `tmux/` owns repo-managed workspace/session templates for optional tmux orchestration.
- `scripts/` owns platform detection, package installation, backups, and symlink creation.
- `Brewfile` and `packages/apt.txt` own package inventories for supported platforms.

## Layout by ownership

```text
dotfiles/
  shared/   # cross-platform config used everywhere possible
  macos/    # macOS-only overlays
  linux/    # native Ubuntu/Linux overlays
  wsl/      # WSL-only overlays
tmux/
  sessions/   # public tmux session templates
  workspaces/ # public multi-session workspace definitions
scripts/
  setup.sh
  tmux-session.sh
  setup-macos.sh
  setup-linux.sh
  setup-wsl.sh
  lib/
    common.sh
    linking.sh
```

## Shared core vs platform overlays

### `dotfiles/shared`

Shared content is the default source of truth for tools that should behave the same across platforms:

- `dotfiles/shared/dev-environment/` — optional additive feature files linked under `~/.config/dev-environment/`
- `dotfiles/shared/shell/starship.toml` — Starship prompt config
- `dotfiles/shared/tmux/tmux.conf` — tmux config
- `dotfiles/shared/nvim/` — the full Neovim config directory, including `init.lua` and `lazy-lock.json`

This directory is treated as the common layer. Platform scripts link these paths into the user's home directory without copying them.

### `dotfiles/macos`

macOS overlay content is only for settings that differ because of the host OS:

- `dotfiles/macos/zsh/.zprofile`
- `dotfiles/macos/zsh/.zshrc`
- `dotfiles/macos/ghostty/config.ghostty`

Ownership here is limited to macOS shell startup files and the macOS Ghostty config.

### `dotfiles/linux`

Linux overlay content covers native Ubuntu/Linux behavior:

- `dotfiles/linux/bash/.profile`
- `dotfiles/linux/bash/.bashrc`
- `dotfiles/linux/ghostty/config.ghostty`

WSL reuses the Linux shell files, so this overlay owns the Bash entrypoints for both native Linux and WSL.

### `dotfiles/wsl`

WSL-specific content is reserved for Windows-side integration:

- `dotfiles/wsl/windows-terminal/settings.json`

This overlay does not replace the shared editor or prompt layer. It only adds the Windows Terminal template when explicitly requested.

## Scripts and manifests

- `scripts/setup.sh` is the dispatcher. It detects the platform and hands off to the matching setup script.
- `scripts/setup-macos.sh` installs packages from `Brewfile` and links the macOS + shared config.
- `scripts/setup-linux.sh` installs packages from `packages/apt.txt`, installs Starship directly, installs Ghostty and the Nerd Font, and links the Linux + shared config.
- `scripts/setup-wsl.sh` installs packages from `packages/apt.txt`, installs Starship directly, links the Linux shell files plus shared config, and can also link the WSL Windows Terminal template.
- `scripts/lib/common.sh` owns shared helpers such as platform detection, package-manager checks, optional installers, and command validation.
- `scripts/lib/linking.sh` owns directory creation, backup behavior, and all symlink creation through `link_file` and `link_dir`.

Package manifests are intentionally separate from dotfiles:

- `Brewfile` defines the macOS package set.
- `packages/apt.txt` defines the Ubuntu/WSL apt package set.

## tmux orchestration layout

The optional tmux workspace layer lives outside `dotfiles/` on purpose.

- `dotfiles/shared/tmux/tmux.conf` is still the linked home-directory tmux config.
- `tmux/sessions/` contains public, generic session templates.
- `tmux/workspaces/` contains public workspace definitions that can start one or more sessions together.
- `scripts/tmux-session.sh` is the stable user-facing wrapper.

This split keeps linked home config separate from launch metadata.

### Public repo vs sibling private overlay

The public repo should only ship generic, shareable templates.

A sibling private overlay repo can hold personal defaults, private workspace details, and optional base-config overrides, for example:

```text
../dev-environment-private/
  tmux/
    defaults.yaml
    sessions/
    workspaces/
  dotfiles/
    shared/
      nvim/
        theme.lua
      tmux/
        tmux.conf
      shell/
        starship.toml
    macos/
      zsh/
        .zprofile
        .zshrc
      ghostty/
        config.ghostty
    linux/
      bash/
        .profile
        .bashrc
      ghostty/
        config.ghostty
```

That private overlay is where personal project names, local defaults, private paths, user-specific shell/prompt/terminal overrides, and personal Neovim theme selection should live.

Wrapper discovery is expected to work like this:

1. public templates from `dev-environment/tmux/`
2. sibling private overlay repo templates if the overlay exists
3. private definitions can extend or override public ones by name

The wrapper should remain useful even when the sibling overlay repo does not exist.

## Managed path mapping

The setup scripts create symlinks from absolute paths inside this repo into the user's home directory. Existing unmanaged files are moved aside first as timestamped backups.

### Shared mappings

| Repo path | Home path |
| --- | --- |
| `dotfiles/shared/dev-environment/` files | `~/.config/dev-environment/` |
| generated Starship config from public baseline plus optional private override | `~/.config/starship.toml` |
| `dotfiles/shared/tmux/tmux.conf` | `~/.tmux.conf` |
| `dotfiles/shared/nvim/` | `~/.config/nvim` |

### macOS mappings

| Repo path | Home path |
| --- | --- |
| `dotfiles/macos/zsh/.zprofile` | `~/.zprofile` |
| `dotfiles/macos/zsh/.zshrc` | `~/.zshrc` |
| generated Ghostty config from public baseline plus optional private override | `~/.config/ghostty/config.ghostty` |

`setup-macos.sh` also backs up legacy Ghostty config locations under `~/Library/Application Support/com.mitchellh.ghostty/` and `~/.config/ghostty/config` so the repo-managed path becomes the single owned target.

### Linux mappings

| Repo path | Home path |
| --- | --- |
| `dotfiles/linux/bash/.profile` | `~/.profile` |
| `dotfiles/linux/bash/.bashrc` | `~/.bashrc` |
| generated Ghostty config from public baseline plus optional private override | `~/.config/ghostty/config.ghostty` |

### WSL mappings

WSL links the same shared paths and Linux Bash files:

| Repo path | Home path |
| --- | --- |
| `dotfiles/linux/bash/.profile` | `~/.profile` |
| `dotfiles/linux/bash/.bashrc` | `~/.bashrc` |
| `dotfiles/wsl/windows-terminal/settings.json` | Windows Terminal `settings.json` under `%LOCALAPPDATA%` |

The WSL Windows Terminal link is conditional on `--apply-windows-terminal`; the rest of the shared and Linux-owned links are part of the normal WSL setup path.
