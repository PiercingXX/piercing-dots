---@diagnostic disable: undefined-global
-- Leaders must be set before most mappings
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Core options and keymaps
require("config.options")

-- Use Neovim's built-in package manager
require("config.pack")

-- Global keymaps
require("config.keymaps")

-- Domain/filetype mappings
require("mappings.rust")
require("mappings.markdown")

local utils = {}

-- fixes parenthesis issue with directories and telescope
function utils.fix_telescope_parens_win()
	if vim.fn.has("win32") then
		local ori_fnameescape = vim.fn.fnameescape
		---@diagnostic disable-next-line: duplicate-set-field
		vim.fn.fnameescape = function(...)
			local result = ori_fnameescape(...)
			return result:gsub("\\", "/")
		end
	end
end

function utils.expand_path(path)
	if path:sub(1, 1) == "~" then
		return os.getenv("HOME") .. path:sub(2)
	end
	return path
end

function utils.center_in(outer, inner)
	return (outer - inner) / 2
end

return utils
