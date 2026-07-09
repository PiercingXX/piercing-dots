-- Leaders must be set before most mappings
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Enable Lua module loader cache (Neovim >=0.9) for faster startup
pcall(function() vim.loader.enable() end)

-- Core options and keymaps
require("config.options")

-- Use Neovim's built-in package manager
require("config.pack")

-- Enable system clipboard
vim.opt.clipboard = "unnamedplus"

-- Global keymaps
require("config.keymaps")

-- Domain/filetype mappings
require("mappings.rust")
require("mappings.markdown")
return require("utils")
