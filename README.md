# dev-environment

Bootstrap repo for a personal terminal/editor environment on macOS, Ubuntu, and Ubuntu on WSL. It installs the in-scope packages for each platform and links the tracked config in this repo into your home directory.

This repo manages the terminal/editor layer only. It does **not** try to do full machine provisioning, manage VS Code, or remove unrelated packages.

## Supported platforms

- macOS
- Ubuntu
- Ubuntu on WSL

## What it manages

The setup links managed config into standard home-directory locations such as shell startup files, `~/.tmux.conf`, `~/.config/nvim`, `~/.config/starship.toml`, Ghostty config, and, on WSL with opt-in, Windows Terminal `settings.json`.

- package install via `Brewfile` on macOS
- package install via `packages/apt.txt` plus direct Starship and pinned Neovim (release tarball, currently 0.12.4) installs on Ubuntu and WSL
- shared `tmux`, Neovim, and Starship config in `dotfiles/shared/`
- macOS `zsh` and Ghostty config in `dotfiles/macos/`
- Ubuntu `bash` and Ghostty config in `dotfiles/linux/`
- optional Windows Terminal settings template for WSL in `dotfiles/wsl/windows-terminal/`
- pinned Neovim plugins via `dotfiles/shared/nvim/lazy-lock.json`
- JetBrains Mono Nerd Font

## Quick start

```bash
scripts/te setup
scripts/te setup --dry-run
```

After setup links `te` into `~/.local/bin`, you can run the same command from anywhere:

```bash
te setup
te setup --dry-run
```

Optional tmux workspace orchestration:

```bash
scripts/te setup --install-tmuxinator
te tmux list
te tmux start public-day
```

Optional .NET 10 SDK install:

```bash
scripts/te setup --install-dotnet
```

Optional Neovim .NET layer:

```bash
scripts/te setup --enable-dotnet-nvim
```

WSL can also link the tracked Windows Terminal settings template:

```bash
scripts/te setup --apply-windows-terminal
scripts/te setup --dry-run --apply-windows-terminal
```

## Safe re-runs

Re-running `te setup` is expected.

- existing correct symlinks are left in place
- conflicting managed destinations are moved to timestamped `*.backup.YYYYMMDD-HHMMSS` paths before linking
- the setup installs missing in-scope tools and relinks managed config
- it does not uninstall unrelated software or do cleanup by default

## Shared core vs platform overlays

- `dotfiles/shared/` is the common core: `tmux`, Neovim, and Starship
- `dotfiles/macos/` adds macOS shell and Ghostty config
- `dotfiles/linux/` adds Ubuntu shell and Ghostty config
- `dotfiles/wsl/` adds the Windows-side Terminal overlay used with WSL
- `scripts/setup.sh` detects the platform and dispatches to the matching setup script

## Private overlay repo

Personal overrides, private tmux defaults, and private workspaces live in an optional, separate private repo. The scripts look for it as a sibling of this repo, under the exact name `dev-environment-private`:

```text
repos/
├── gatorteef/                 # this repo
└── dev-environment-private/   # private overlay (optional)
```

- the default path is `../dev-environment-private`, resolved in `scripts/lib/private-overrides.sh` and `scripts/tmux-session.sh`
- the name is `dev-environment-private` even though this repo is now `gatorteef`; renaming the private repo (for example to `gatorteef-private`) breaks discovery unless you also set an override
- to keep it somewhere else or under another name, set `PRIVATE_REPO_ROOT` or `DEV_ENV_PRIVATE_REPO` to its path
- `te doctor` and `te paths` report the resolved private repo root and whether it was found
- `$HOME/.config/dev-environment/private/...` paths in the shell, tmux, and Neovim configs are where setup links the private override files; they are not the repo's location

## Notes

- Ghostty is part of the managed setup on macOS and standalone Ubuntu, not WSL
- .NET 10 SDK install is optional through `--install-dotnet`
- the optional Neovim .NET layer is enabled through `--enable-dotnet-nvim` and expects `dotnet` to already be available
- the first Neovim launch may finish plugin or treesitter bootstrap work
- Oh My Zsh removal is intentionally out of scope; only clean it up after the managed shell setup is working
- tmux workspace orchestration is optional and uses generic public templates plus an optional sibling private overlay repo for personal defaults and private workspaces
- base config overrides can also live in the sibling private repo; edit the private file and re-run `bash scripts/setup.sh` to apply it
- when the sibling private repo exists, setup scaffolds missing private override files for the current platform without overwriting existing ones
- `scripts/setup.sh` and `scripts/tmux-session.sh` remain as backend entry points, but `te` is now the preferred user-facing CLI

## Documentation

This README is the quick entry point. Deeper setup docs live at:

- [`docs/index.md`](docs/index.md)
- [`docs/setup/setup.md`](docs/setup/setup.md)
- [`docs/setup/repo-layout.md`](docs/setup/repo-layout.md)
- [`docs/setup/maintenance.md`](docs/setup/maintenance.md)
- [`docs/setup/tmux-workspaces.md`](docs/setup/tmux-workspaces.md)
- [`docs/tutorial/index.md`](docs/tutorial/index.md)
- [`docs/tutorial/dotnet.md`](docs/tutorial/dotnet.md)
