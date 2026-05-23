vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.keymap.set({ "n", "v" }, "<Space>", "<Nop>", { silent = true })

local opt = vim.opt

opt.number = true
opt.relativenumber = true
opt.mouse = "a"
opt.clipboard = "unnamedplus"
opt.breakindent = true
opt.undofile = true
opt.ignorecase = true
opt.smartcase = true
opt.updatetime = 250
opt.timeoutlen = 500
opt.signcolumn = "yes"
opt.termguicolors = true
opt.splitright = true
opt.splitbelow = true
opt.cursorline = true
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.smartindent = true

vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")
vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "Move to left window" })
vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "Move to lower window" })
vim.keymap.set("n", "<C-k>", "<C-w>k", { desc = "Move to upper window" })
vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "Move to right window" })

vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight when yanking text",
  group = vim.api.nvim_create_augroup("highlight-yank", { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

vim.diagnostic.config({
  severity_sort = true,
  float = { border = "rounded" },
  underline = true,
  update_in_insert = false,
  virtual_text = {
    prefix = "●",
    spacing = 2,
  },
})

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
local uv = vim.uv or vim.loop
local dev_environment_config_dir = vim.fs.joinpath(vim.fs.dirname(vim.fn.stdpath("config")), "dev-environment")
local dotnet_nvim_enabled = uv.fs_stat(vim.fs.joinpath(dev_environment_config_dir, "enable-dotnet-nvim")) ~= nil
local os_uname = uv.os_uname()
local private_theme_config_path = vim.fs.joinpath(
  dev_environment_config_dir,
  "private",
  "dotfiles",
  "shared",
  "nvim",
  "theme.lua"
)

local function read_system_output(command)
  local output = vim.fn.system(command)
  if vim.v.shell_error ~= 0 then
    return nil
  end

  return vim.trim(output)
end

local function detect_os_background()
  if uv.os_uname().sysname == "Darwin" and vim.fn.executable("defaults") == 1 then
    local appearance = read_system_output({ "defaults", "read", "-g", "AppleInterfaceStyle" })
    if appearance == "Dark" then
      return "dark"
    end

    return "light"
  end

  if vim.o.background == "light" then
    return "light"
  end

  return "dark"
end

local function load_private_theme_config()
  if not uv.fs_stat(private_theme_config_path) then
    return nil
  end

  local ok, theme_config = pcall(dofile, private_theme_config_path)
  if not ok then
    error("Failed to load private Neovim theme config:\n" .. theme_config)
  end

  if type(theme_config) ~= "table" then
    error("Private Neovim theme config must return a table:\n" .. private_theme_config_path)
  end

  return theme_config
end

local function resolve_colorscheme_for_background(background)
  local theme_config = load_private_theme_config()
  if not theme_config then
    return "dark", "catppuccin-mocha"
  end

  background = background or detect_os_background()
  local colorscheme = theme_config[background]

  if type(colorscheme) ~= "string" or colorscheme == "" then
    error(
      string.format(
        "Private Neovim theme config must define a non-empty %s theme:\n%s",
        background,
        private_theme_config_path
      )
    )
  end

  return background, colorscheme
end

local function apply_colorscheme(background)
  local resolved_background, colorscheme = resolve_colorscheme_for_background(background)
  if vim.o.background == resolved_background and vim.g.colors_name == colorscheme then
    return
  end

  vim.o.background = resolved_background
  vim.cmd.colorscheme(colorscheme)
end

local function should_enable_auto_dark_mode()
  if string.match(os_uname.release, "WSL") or string.match(os_uname.release, "orbstack") then
    return true
  end

  if os_uname.sysname == "Darwin" or os_uname.sysname == "Windows_NT" then
    return true
  end

  return os_uname.sysname == "Linux" and vim.fn.executable("dbus-send") == 1
end

local function setup_auto_dark_mode()
  if not should_enable_auto_dark_mode() then
    return
  end

  require("auto-dark-mode").setup({
    set_dark_mode = function()
      apply_colorscheme("dark")
    end,
    set_light_mode = function()
      apply_colorscheme("light")
    end,
    update_interval = 3000,
    fallback = "dark",
  })
end

local function refresh_colorscheme()
  apply_colorscheme()
end

if not uv.fs_stat(lazypath) then
  local out = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--branch=stable",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })

  if vim.v.shell_error ~= 0 then
    error("Failed to clone lazy.nvim:\n" .. out)
  end
end

vim.opt.rtp:prepend(lazypath)

local plugins = {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
  },
  {
    "rebelot/kanagawa.nvim",
    name = "kanagawa",
    priority = 1000,
  },
  {
    "f-person/auto-dark-mode.nvim",
    lazy = false,
    config = setup_auto_dark_mode,
  },
  {
    "nvim-lua/plenary.nvim",
    lazy = true,
  },
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    config = function()
      require("which-key").setup()
    end,
  },
  {
    "lewis6991/gitsigns.nvim",
    event = "VeryLazy",
    opts = {},
  },
  {
    "nvim-tree/nvim-web-devicons",
    lazy = true,
  },
  {
    "nvim-telescope/telescope.nvim",
    cmd = "Telescope",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    keys = {
      { "<leader>ff", "<cmd>Telescope find_files<CR>", desc = "Find files" },
      { "<leader>fg", "<cmd>Telescope live_grep<CR>", desc = "Live grep" },
      { "<leader>fb", "<cmd>Telescope buffers<CR>", desc = "Buffers" },
      { "<leader>fh", "<cmd>Telescope help_tags<CR>", desc = "Help tags" },
    },
    opts = {},
  },
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    lazy = false,
    config = function()
      local languages = {
        "bash",
        "json",
        "lua",
        "markdown",
        "markdown_inline",
        "query",
        "toml",
        "vim",
        "vimdoc",
        "yaml",
      }

      if dotnet_nvim_enabled then
        table.insert(languages, 2, "c_sharp")
      end

      local treesitter = require("nvim-treesitter")

      treesitter.setup({
        install_dir = vim.fn.stdpath("data") .. "/site",
      })

      local install = treesitter.install(languages)
      if install and install.wait then
        install:wait(300000)
      end

      vim.api.nvim_create_autocmd("FileType", {
        pattern = "*",
        callback = function(args)
          pcall(vim.treesitter.start, args.buf)
        end,
      })
    end,
  },
  {
    "OXY2DEV/markview.nvim",
    ft = "markdown",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
      "nvim-treesitter/nvim-treesitter",
    },
    opts = {
      modes = { "n", "no", "c" },
      hybrid_modes = { "n" },
    },
    keys = {
      { "<leader>mt", "<cmd>Markview toggle<CR>", desc = "Toggle markdown preview" },
      { "<leader>mh", "<cmd>Markview hybridToggle<CR>", desc = "Toggle markdown hybrid" },
      { "<leader>ms", "<cmd>Markview splitToggle<CR>", desc = "Toggle markdown split" },
    },
  },
}

if dotnet_nvim_enabled then
  local ok, dotnet_plugins = pcall(require, "dev_environment.dotnet")
  if not ok then
    error("Failed to load optional .NET Neovim config:\n" .. dotnet_plugins)
  end

  vim.list_extend(plugins, dotnet_plugins)
end

require("lazy").setup(plugins, {
  install = {
    colorscheme = { "kanagawa", "catppuccin", "habamax" },
  },
})

refresh_colorscheme()

vim.api.nvim_create_autocmd({ "FocusGained", "VimResume" }, {
  desc = "Refresh colorscheme when the OS appearance changes",
  group = vim.api.nvim_create_augroup("refresh-colorscheme", { clear = true }),
  callback = refresh_colorscheme,
})
