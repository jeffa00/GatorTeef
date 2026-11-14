# Maintenance

## Safe re-runs

Run maintenance from the repo root:

```bash
cd /path/to/GatorTeef
bash scripts/setup.sh --dry-run
bash scripts/setup.sh
```

On WSL, include `--apply-windows-terminal` when you also want to manage Windows Terminal again.

Re-runs are designed to be safe:

- package installs are re-applied through Homebrew or `apt`, but already-installed items are generally skipped
- an existing managed symlink is left alone when it already points at this repo
- Linux only installs Ghostty if missing, and Linux/WSL only install the Nerd Font if it is not already present

## What gets backed up

Before replacing an existing destination, the scripts move it to a timestamped backup like:

```text
<path>.backup.YYYYMMDD-HHMMSS
```

That applies to managed destinations such as shell files, `~/.tmux.conf`, `~/.config/starship.toml`, `~/.config/nvim`, Ghostty config, and the optional WSL Windows Terminal `settings.json`.

Extra backup behavior:

- macOS also backs up legacy Ghostty files in `~/.config/ghostty/config` and old `~/Library/Application Support/com.mitchellh.ghostty/` locations
- Linux also backs up a plain file at `~/.config/ghostty/config`

## Update the repo and reapply

When the tracked config changes:

```bash
cd /path/to/GatorTeef
git pull --ff-only
bash scripts/setup.sh --dry-run
bash scripts/setup.sh
```

If you are on WSL and manage Windows Terminal from this repo, re-run with `--apply-windows-terminal`.

Because the home paths are symlinks into this repo, many changes take effect as soon as the repo files change. Re-running is still the right step after updates because it refreshes packages, restores any missing links, regenerates composed config files, and applies optional targets again.

## If destination files already exist

Expected conflict handling:

- **same managed target already linked:** no change; the script logs `Already linked`
- **file, directory, or symlink exists at the destination but points elsewhere:** it is moved to a timestamped backup, then replaced with the managed symlink
- **type mismatch:** the script stops instead of replacing a directory with a file link or a file with a directory link

If the script stops on a type mismatch, move or remove the conflicting path yourself, then re-run.

## What to expect from managed symlinks

- links use absolute paths back into this repository
- editing the file through the home path edits the tracked file in the repo
- moving or renaming the repo breaks the links; keep the repo in a stable location or re-run setup after relocating it
- `~/.config/nvim` is a symlink to the whole tracked directory, not a copied snapshot

## Optional migration cleanup

After a full re-run and verification in a new shell, you can clean up old tooling manually. Example:

- remove Oh My Zsh only after the managed `.zshrc` and `.zprofile` are working as expected
- review and delete old `.backup.*` files you no longer need
- remove obsolete legacy Ghostty files only after confirming the managed config is the one in use
