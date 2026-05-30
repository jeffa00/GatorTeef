# Neovim in this environment

This environment links the repo-managed Neovim config into `~/.config/nvim`, so the behavior described here is the shared setup, not a one-off local tweak.

## What this setup is trying to be

This Neovim config is intentionally small and practical:

- plain Neovim with a shared `init.lua`
- plugin management through `lazy.nvim`
- fast file and text search through Telescope
- file browsing through Neo-tree
- syntax support through treesitter
- markdown-friendly preview tools through Markview
- a few opinionated defaults for navigation, clipboard, splits, and indentation
- an optional .NET layer that can be enabled separately when you want C# support

It is **not** a heavily customized IDE. By default there is no repo-managed LSP, completion framework, or large custom command layer. Expect a clean editor with a few well-chosen tools.

## Launching Neovim

Common ways to start it:

```bash
nvim
nvim path/to/file.md
nvim .
```

Recommended habit: **start Neovim from the project or notes directory you want to work in**.

That matters because Telescope searches the current working directory. For example:

```bash
cd ~/path/to/notes
nvim .
```

If your shell or another tool opens `$EDITOR`, it will also use Neovim in this setup because the managed shell config exports:

```bash
EDITOR=nvim
VISUAL=nvim
```

That means commands like `git commit` will usually drop you into Neovim automatically.

## First-run and bootstrap expectations

On the first launch after setup, Neovim may do a little work before it feels "ready":

1. `lazy.nvim` bootstraps itself if it is not already installed.
2. Pinned plugins are installed from the lockfile.
3. treesitter parsers for the managed languages may install or update.

This is expected. The setup docs already call out that the first Neovim launch may need time to finish plugin and treesitter bootstrap.

Practical advice:

- let the first launch finish before judging whether something is broken
- if startup looks busy, wait instead of killing it immediately
- after bootstrap, later launches should be much faster

## Managed defaults and conventions

These are the main editor behaviors coming from the tracked config.

### Leader key

The leader key is **Space**.

If you press `Space` and pause briefly, `which-key` can show the available leader mappings.

### Editing defaults

The config enables:

- line numbers
- relative line numbers
- mouse support
- system clipboard integration
- persistent undo
- smart case-insensitive searching
- a visible sign column
- true color
- cursor line highlight
- automatic indentation with spaces, not tabs
- 2-space indent width
- new vertical splits opening to the right
- new horizontal splits opening below

In practice, that means:

- movement by line number is easy because relative numbers are on
- copied text can go to the system clipboard
- undo history survives across sessions
- searching for `note` ignores case, while searching for `Note` respects case
- markdown and config files use two spaces by default

### Small quality-of-life behaviors

- `Esc` in normal mode clears search highlighting
- yanked text briefly highlights so you can see what was copied
- diagnostics use rounded floating windows when they appear
- without a private theme override, the default colorscheme is `catppuccin-mocha`
- a sibling private overlay can define `dotfiles/shared/nvim/theme.lua` to choose light and dark themes separately
- on supported systems, `auto-dark-mode.nvim` polls the OS appearance and reapplies the matching private light or dark theme while Neovim stays open

## Everyday navigation and window use

This guide focuses on the managed setup, but these core motions are worth using every day:

- `i` — enter insert mode
- `Esc` — return to normal mode
- `:w` — save
- `:q` — quit
- `:wq` — save and quit
- `/text` — search forward
- `n` / `N` — jump to next/previous match
- `u` — undo
- `Ctrl-r` — redo

### Split navigation

The config adds easy movement between Neovim windows:

- `Ctrl-h` — move to the split on the left
- `Ctrl-j` — move to the split below
- `Ctrl-k` — move to the split above
- `Ctrl-l` — move to the split on the right

Create splits with the usual Vim commands, then move between them with those shortcuts:

```vim
:split
:vsplit
```

Because splits open right and below by default, the layout is predictable.

## File search and workspace search

This setup uses Telescope for the main search flows and Neo-tree when you want a persistent file sidebar.

### Keybindings

- `Space e` — toggle the Neo-tree file sidebar and reveal the current file
- `Space f f` — find files
- `Space f g` — live grep text in the current working directory
- `Space f b` — switch buffers
- `Space f h` — search help tags

### How to use it well

#### Find a file

Open Neovim in the directory you care about, then press:

```text
Space f f
```

Start typing part of a filename and press Enter.

Example:

1. `cd ~/path/to/notes`
2. `nvim .`
3. `Space f f`
4. type `tmux`
5. press Enter on the note you want

#### Browse the working tree

If you want a visible sidebar instead of search-first navigation, press:

```text
Space e
```

That toggles Neo-tree on the left side, shows dotfiles and gitignored files, follows the file you have open, and shows diagnostics in the tree.

Practical uses:

- browse nearby files without leaving the keyboard
- expand directories while staying in the current project
- keep a file tree open in one split while editing in another
- work comfortably in repos where important config lives in hidden files like `.gitignore`, `.bashrc`, or `.env`

Within the Neo-tree window, use `Enter` to open a file or expand/collapse a directory.

While Neo-tree is focused, press `H` to toggle hidden and filtered items on or off.

#### Search across a repo or notes directory

```text
Space f g
```

Type the text you want to search for and Telescope will use ripgrep to show matches.

Good uses:

- find every note mentioning `ghostty`
- find unfinished checklist items by searching for `- [ ]`
- search config files for `clipboard` or `tmux`

#### Switch between open files

```text
Space f b
```

This is the quick way to bounce between a few active buffers without reopening them from scratch.

### Practical expectations

- `find_files` is best when you roughly know the filename
- `live_grep` is best when you know text inside the file
- Neo-tree is best when you want to browse the project structure visually
- searches are rooted in the directory where you launched Neovim
- this setup installs `fd`, `fzf`, and `ripgrep`, so the search workflow is designed around those command-line tools being present

## Markdown workflow

This environment is clearly optimized for markdown-heavy work.

### Built for markdown notes and docs

treesitter is explicitly installed for:

- `markdown`
- `markdown_inline`
- `yaml`
- `json`
- `toml`
- `lua`
- `bash`
- `vim`
- `vimdoc`
- `query`

That makes the setup especially comfortable for:

- notes
- documentation
- README edits
- shell/config work

### Markdown preview controls

In markdown buffers, Markview adds these leader mappings:

- `Space m t` — toggle markdown preview
- `Space m h` — toggle hybrid markdown view
- `Space m s` — toggle split markdown view

You do not need these all the time. A simple workflow is:

1. open a markdown file
2. write normally
3. use `Space m t` when you want a richer preview
4. use `Space m s` if you want a split-oriented preview workflow
5. toggle it back off when you want a plain editing view again

If you prefer mostly raw markdown, that is fine too. This setup does not force preview mode on you.

### A practical note-writing flow

Example:

```bash
cd ~/path/to/notes
nvim .
```

Then inside Neovim:

1. `Space f f` to open or create the note you want
2. write headings, lists, links, and code fences normally
3. use `Space m t` if you want to preview rendered markdown
4. use `/` search to jump around long notes
5. use `Space f g` to search across the whole notes repo

Because the repo is markdown-first and this config keeps the editor fairly plain, files stay easy to edit in either Neovim or VS Code.

## Git-aware editing

This setup includes `gitsigns.nvim`, so in a git repo you may see change markers in the sign column next to modified lines.

That is helpful context while editing, but there are **no custom git keybindings defined in this config**. For git actions, expect to keep using normal terminal commands such as:

```bash
git status
git diff
git commit
```

A very practical pattern is to keep Neovim open in one tmux pane and git commands in another.

## Working well with tmux

This environment is designed for tmux and Neovim to be used together.

### tmux behaviors from the managed config

The shared tmux config enables:

- mouse support
- clipboard integration
- vi-style copy mode keys
- pane and window numbering starting at 1
- automatic renumbering of windows

Useful tmux bindings from the managed config:

- `prefix + |` — split pane vertically
- `prefix + -` — split pane horizontally
- `prefix + c` — create a new window
- `prefix + h/j/k/l` — move between tmux panes
- `prefix + r` — reload tmux config

### Neovim splits vs tmux panes

A good mental model:

- use **Neovim splits** for closely related files in one editing task
- use **tmux panes** when you want editor + shell side by side
- use **tmux windows** for separate task contexts

Also note the navigation pattern:

- inside **Neovim**, use `Ctrl-h/j/k/l` to move between editor splits
- inside **tmux**, use `prefix + h/j/k/l` to move between tmux panes

The keys are intentionally similar, but they are not the same layer.

### Example tmux + Neovim workflow

1. Start tmux.
2. Open a pane for Neovim.
3. Split another pane for shell commands.
4. In the editor pane, run `nvim .` from the repo root.
5. In the shell pane, run `git status`, `git diff`, tests, or search commands.

That gives you a very efficient "edit here, verify there" setup.

## What not to expect from this config

To avoid confusion, here is what this managed setup does **not** currently provide:

- no repo-managed language server setup by default
- no repo-managed autocompletion framework
- no large custom command palette beyond Telescope and which-key
- no custom cross-over tmux/Neovim navigation plugin

That is intentional. The setup is lightweight and focused on editing, search, markdown work, and terminal-driven workflows.

## Optional .NET mode

Phase 9 adds an opt-in .NET Neovim layer for users who want lightweight C# support without turning the shared config into a general-purpose IDE.

For the end-to-end .NET workflow in this repo, including CLI usage and debugging flow, see [`.NET in this environment`](./dotnet.md).

Enable it with:

```bash
bash scripts/setup.sh --enable-dotnet-nvim
```

It expects `dotnet` to already be installed, either through:

```bash
bash scripts/setup.sh --install-dotnet
```

or through an existing SDK install on the machine.

When enabled, the config adds:

- C# treesitter support
- Mason configured with the extra registry needed for Roslyn
- the Roslyn language server wired through Neovim's LSP config
- `nvim-dap` wired to `netcoredbg` for lightweight .NET debugging

The intent is still lightweight:

- no repo-managed completion framework
- no heavyweight IDE layer

Install the Neovim-side tools through Mason:

```text
:MasonInstall roslyn
:MasonInstall netcoredbg
```

### C# keybindings

When the Roslyn LSP is attached in a C# buffer, this layer adds a small set of LSP mappings:

- `gd` — go to definition
- `gr` — list references
- `K` — hover
- `Space r n` (`<leader>rn`) — rename symbol
- `Space c a` (`<leader>ca`) — code action

These only apply in Roslyn-backed C# buffers; the default non-.NET Neovim experience stays unchanged.

### Debug keybindings

In C# buffers with the optional .NET layer enabled:

- `Space d c` (`<leader>dc`) — start or continue debugging
- `Space d b` (`<leader>db`) — toggle breakpoint
- `Space d i` (`<leader>di`) — step into
- `Space d o` (`<leader>do`) — step over
- `Space d O` (`<leader>dO`) — step out
- `Space d r` (`<leader>dr`) — open the DAP REPL
- `Space d q` (`<leader>dq`) — terminate the debug session

### Debug flow

The default launch configuration prompts for the compiled `.dll` path.

A practical workflow is:

1. build the project first, for example with `dotnet build`
2. press `Space d c`
3. enter the path to the built `.dll`
4. use the breakpoint and stepping mappings while the session is running

There is also an **Attach to process** configuration for attaching to an already-running .NET process.

## Troubleshooting

### First launch seems slow

That is usually plugin bootstrap or treesitter installation.

What to do:

- wait for the first launch to finish
- quit and reopen Neovim after bootstrap completes

### `lazy.nvim` fails to install

The config clones `lazy.nvim` from GitHub on first use.

Check:

- `git` is installed and on `PATH`
- network access is working
- you can reach GitHub from the machine

### `Space f g` does not work

`live_grep` depends on `ripgrep`.

Check:

```bash
rg --version
```

Also make sure you started Neovim in the directory you actually want to search.

### `Space f f` is not finding the file you expected

Usually one of these is true:

- you launched Neovim from the wrong directory
- the file is outside the current working tree

A reliable fix is:

```bash
cd /path/to/project
nvim .
```

If you want to browse instead of search, use `Space e` to open Neo-tree.

### Clipboard copy/paste feels wrong

This setup enables clipboard integration in both Neovim and tmux, but clipboard behavior still depends on the terminal and OS session being healthy.

If it feels off:

- confirm you are in the managed terminal environment
- confirm tmux is using the tracked config
- try yanking in Neovim again after opening a fresh terminal session

### Markdown preview commands do nothing

Markview is loaded for markdown buffers.

Check:

- you are editing a markdown file
- the filetype is really markdown
- you used one of the markdown mappings: `Space m t`, `Space m h`, or `Space m s`

### A keybinding does not seem to exist

This config intentionally defines only a small number of custom mappings. If you are expecting a common plugin mapping from some other Neovim setup, it may simply not be part of this one.

When in doubt:

- press `Space` and wait for `which-key`
- use `:help`
- fall back to standard Vim commands

## Recommended daily habits

If you want this setup to feel natural quickly, these habits help:

1. launch `nvim .` from the directory you actually want to work in
2. use `Space f f` for filenames and `Space f g` for text search
3. use tmux panes for editor + shell side by side
4. use `Ctrl-h/j/k/l` inside Neovim splits
5. use `Space m ...` only when working in markdown
6. remember that the setup is intentionally lightweight; when unsure, standard Vim behavior is usually the right fallback

That combination matches what this environment is optimized for: terminal-first editing, markdown-heavy notes and docs, and quick movement between Neovim, tmux, and shell commands.
