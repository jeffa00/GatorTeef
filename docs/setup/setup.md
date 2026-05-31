# Setup Guide

Use this guide to bootstrap a new machine or re-apply the managed terminal environment from the repository root.

## Prerequisites

Before you start:

- Clone this repository locally.
- Make sure you have internet access for package downloads.
- Run the script as a user with `sudo` access on Ubuntu or WSL.
- Start from the repo root: `cd /path/to/dev-environment`

Platform-specific prerequisites:

- **macOS:** Homebrew must already be installed and available on `PATH`.
- **Ubuntu:** This setup currently supports Ubuntu only. `apt-get` must be available.
- **WSL:** Run inside an Ubuntu WSL distro. If you want the Windows Terminal template linked too, Windows Terminal must already be installed on the Windows side.

## Run the bootstrap

Standard run:

```bash
scripts/te setup
```

Preview the work first:

```bash
scripts/te setup --dry-run
```

After setup links `te` into `~/.local/bin`, you can run the same commands from anywhere:

```bash
te setup
te setup --dry-run
```

On WSL, also link the tracked Windows Terminal settings template:

```bash
scripts/te setup --apply-windows-terminal
```

You can combine flags when needed, for example:

```bash
scripts/te setup --dry-run --apply-windows-terminal
```

Optional .NET 10 SDK install:

```bash
bash scripts/setup.sh --install-dotnet
```

You can combine it with dry-run too:

```bash
bash scripts/setup.sh --dry-run --install-dotnet
```

Optional Neovim .NET layer:

```bash
bash scripts/setup.sh --enable-dotnet-nvim
```

## Optional tmux workspace orchestration

Phase 8 adds an optional tmux workspace layer on top of the base shell/editor setup.

- The base environment still works without it.
- The public interface is `scripts/tmux-session.sh`, not raw backend commands.
- Install is opt-in.
- Startup is opt-in.
- Nothing auto-launches from shell startup files.

Install the optional backend:

```bash
scripts/te setup --install-tmuxinator
```

The current backend target is tmuxinator:

- macOS: installed through Homebrew
- Ubuntu and WSL: installed through `apt`

On macOS, if you actively manage Ruby with `rbenv` or `rvm`, review the tmux workspace docs before using the Homebrew path.

Once installed:

```bash
te tmux list
te tmux start public-day
te tmux start dev-environment
```

Running the wrapper without arguments is also supported, but only when you have configured defaults in a sibling private overlay repo.

## Optional .NET 10 SDK installation

Phase 9 adds an optional .NET SDK layer on top of the base environment.

- The base shell/editor environment still works without it.
- Install is opt-in.
- This step installs the SDK only; editor-specific .NET workflow configuration is separate.

Enable it with:

```bash
scripts/te setup --install-dotnet
```

Current install path by platform:

- **macOS:** installs Homebrew `dotnet`
- **Ubuntu 24.04+ / WSL on Ubuntu 24.04+:** installs `dotnet-sdk-10.0` from `apt`
- **Ubuntu 22.04 / WSL on Ubuntu 22.04:** adds `ppa:dotnet/backports`, then installs `dotnet-sdk-10.0`

For the opt-in .NET path, Ubuntu versions older than 22.04 are not supported.

### Optional Neovim .NET layer

The editor integration is a second opt-in layer:

```bash
scripts/te setup --enable-dotnet-nvim
```

- This enables the lightweight Neovim .NET path without changing the default editor experience for everyone.
- It expects `dotnet` to already be available on `PATH`, whether from `--install-dotnet` or an existing install.
- The setup links opt-in files under `~/.config/dev-environment/` so the base shell and Neovim config stay unchanged when the feature is not enabled.

Common combinations:

```bash
scripts/te setup --install-dotnet --enable-dotnet-nvim
scripts/te setup --dry-run --install-dotnet --enable-dotnet-nvim
```

For the day-to-day .NET workflow after setup, see [`.NET in this environment`](../tutorial/dotnet.md).

## What the setup does

At a high level, the bootstrap script:

1. Detects the platform and dispatches to the macOS, Ubuntu, or WSL setup path.
2. Installs packages from the repo-managed manifest:
   - `Brewfile` on macOS
   - `packages/apt.txt` on Ubuntu and WSL
3. Installs Starship directly on Ubuntu and WSL into `~/.local/bin`.
4. Installs or manages the terminal layer for the platform:
   - macOS: installs Ghostty through Homebrew
   - Ubuntu: adds the Ghostty Ubuntu PPA and installs Ghostty
   - WSL: skips Ghostty and uses Windows Terminal instead
5. Installs JetBrains Mono Nerd Font.
6. Symlinks the managed config files for the shell, Starship, tmux, and Neovim.
7. Backs up existing unmanaged files before replacing them with tracked symlinks.
8. Validates key tools such as `tmux`, `nvim`, `ghostty` (where applicable), and `starship`.
9. Optionally installs `tmuxinator` when you pass `--install-tmuxinator`.
10. Optionally installs the .NET 10 SDK when you pass `--install-dotnet`.
11. Optionally enables the Neovim .NET layer when you pass `--enable-dotnet-nvim`.
12. Applies optional private overrides from a sibling `dev-environment-private` repo when those files exist.

Backups use a timestamped suffix such as `.backup.YYYYMMDD-HHMMSS`.

## Dry-run behavior

`--dry-run` is a preview mode for the scripted actions.

In dry-run mode, the helper functions log the commands that would run instead of executing them. In practice, that makes it useful for checking:

- which package manager commands would run
- which files would be linked
- which existing files would be backed up
- which platform path the script would take

Dry-run still performs prerequisite and environment checks, including platform detection, Ubuntu validation on Linux/WSL, and Homebrew availability on macOS. On macOS it also checks whether the `Brewfile` is already satisfied.

Use it as a safety check before the real run, not as a substitute for the actual setup.

## Optional private overrides

The setup can also consume an optional sibling private repo for user-specific overrides.

Default location:

```text
../dev-environment-private/
```

You can override that path with `DEV_ENV_PRIVATE_REPO=/path/to/dev-environment-private`.

Supported private override paths:

```text
tmux/
  defaults.yaml
  sessions/
  workspaces/
dotfiles/
  shared/
    tmux/tmux.conf
    shell/starship.toml
  macos/
    zsh/.zprofile
    zsh/.zshrc
    ghostty/config.ghostty
  linux/
    bash/.profile
    bash/.bashrc
    ghostty/config.ghostty
```

Workflow:

1. Edit the file in `dev-environment-private`.
2. Re-run `bash scripts/setup.sh`.
3. Open a new shell or reload the tool that uses that config.

When the private repo already exists, setup also creates any missing private override starter files for the current platform and the shared override files. Existing private files are left unchanged. For Starship, the scaffolded private `dotfiles/shared/shell/starship.toml` starts as a copy of the shared baseline so you can customize it incrementally.

Behavior by file type:

- tmux base config: public `~/.tmux.conf` loads the private fragment after the shared baseline
- Neovim theme selection: the shared `~/.config/nvim` config can load a private `dotfiles/shared/nvim/theme.lua` file for user-specific light/dark theme choices
- shell files: public shell startup files source private fragments near the end
- Ghostty: setup generates a final config from the public baseline plus appended private overrides
- Starship: setup generates the final `~/.config/starship.toml`, but because TOML cannot safely merge duplicate keys, a private `starship.toml` acts as a full private replacement for the shared baseline

## Platform notes

### macOS

- Requires Homebrew before you begin.
- Uses the tracked `zsh` files: `.zprofile` and `.zshrc`.
- Links Ghostty config to `~/.config/ghostty/config.ghostty`.
- If older Ghostty config files exist in legacy macOS locations, the script backs them up before switching to the tracked config.

### Ubuntu

- Only Ubuntu is supported by the Linux path.
- Uses the tracked `bash` files: `.profile` and `.bashrc`.
- Installs packages from `packages/apt.txt`.
- Installs Starship directly into `~/.local/bin`.
- Installs Ghostty from `ppa:mkasberg/ghostty-ubuntu`.
- Installs JetBrains Mono Nerd Font under `~/.local/share/fonts/JetBrainsMonoNerdFont`.

### WSL

- WSL is treated separately from standalone Linux.
- Uses the Ubuntu package manifest and the tracked `bash` config.
- Installs Starship directly into `~/.local/bin`.
- Does **not** install Ghostty.
- Optionally links the repository's Windows Terminal `settings.json` into the Windows user profile when you pass `--apply-windows-terminal`.
- Before replacing that file or link, setup writes a timestamped backup beside the existing Windows Terminal `settings.json`.
- The Windows Terminal link is created as a Windows-native symlink to a Windows-visible path, so it must be run from inside WSL.

## Manual follow-up after the script finishes

Expect to do a few manual checks after the bootstrap completes:

1. **Open a new shell session** so the linked shell config is picked up.
2. **Launch your terminal app and confirm the font** is JetBrains Mono Nerd Font. The tracked Ghostty config and Windows Terminal template already reference it, but other terminal apps may need a manual font change.
3. **Start `nvim` once** and let the first run finish. Plugin versions are pinned in `dotfiles/shared/nvim/lazy-lock.json`, and the initial launch may still install or update treesitter parsers.
4. **Review any backup files** if the script moved aside existing local config.
5. **On WSL, restart Windows Terminal** after linking the template so the new settings are loaded.
6. **Handle optional cleanup yourself** if needed. For example, removing Oh My Zsh is intentionally not part of this setup flow.
7. **If you enabled tmux workspaces, review the public templates and configure your sibling private overlay repo** before relying on wrapper defaults.
8. **If you use private overrides, re-run setup after editing the private repo** so generated files and managed links stay aligned.
9. **Run `te doctor`** if you want a quick health check of repo discovery, managed paths, and tool availability.

## Expected result

When the script completes successfully, the machine should have the repo-managed terminal/editor packages installed, the tracked dotfiles linked into place, and the core terminal workflow ready for normal use with only the manual follow-up above.
