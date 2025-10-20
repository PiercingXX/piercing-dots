-- PiercingXX

--Swap
vim.opt.swapfile = false

-- Text wrap
vim.opt.textwidth = 0
vim.opt.wrapmargin = 0
vim.opt.wrap = true

-- Always show relative line numbers
vim.opt.number = true
vim.opt.relativenumber = true


-- Tabs
vim.opt.smarttab = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.smartindent = true
vim.opt.autoindent = true


vim.opt.shortmess:append "I"


-- Show line under cursor
vim.opt.cursorline = true
-- Show column of cursor cursor
-- vim.opt.cursorcolumn = true


-- Store undos between sessions
vim.opt.undofile = true


-- Enable mouse mode, can be useful for resizing splits for example!
vim.opt.mouse = "a"


-- Don't show the mode, since it's already in the status line
vim.opt.showmode = false


-- Enable break indent
vim.opt.breakindent = true


-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
vim.opt.ignorecase = true
vim.opt.smartcase = true


-- Keep signcolumn on by default
vim.opt.signcolumn = "yes"


-- Decrease update time
vim.opt.updatetime = 250


-- Configure how new splits should be opened
vim.opt.splitright = true
vim.opt.splitbelow = true


-- Sets how neovim will display certain whitespace characters in the editor.
--  See `:help 'list'`
--  and `:help 'listchars'`
vim.opt.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }


-- Preview substitutions live, as you type!
vim.opt.inccommand = "split"


-- Minimal number of screen lines to keep above and below the cursor.
vim.opt.scrolloff = 10


-- You can prevent Neovim from prompting for a keypress by giving the command-line more space. 
-- If cmdheight is 2 or higher, Neovim will display the full message without pausing. 
vim.opt.cmdheight = 2


-- Highlight text for some time after yanking
vim.api.nvim_create_autocmd("TextYankPost", {
	group = vim.api.nvim_create_augroup("YankHighlight", { clear = true }),
	pattern = "*",
	callback = function()
		vim.highlight.on_yank()
	end,
	desc = "Highlight yank",
})

-- Autosave journal file on BufLeave or BufWinLeave
vim.api.nvim_create_autocmd({ "BufLeave", "BufWinLeave" }, {
	pattern = "/media/Archived-Storage/[03] Other/My Life/02 Journal/*.md",
	callback = function()
		if vim.bo.modified then vim.cmd("write") end
	end,
})

-- Autosave journal on text change
vim.api.nvim_create_augroup("JournalAutosave", { clear = true })
vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
	group = "JournalAutosave",
	pattern = "*/02 Journal/*.md",
	callback = function()
		print("Autosave triggered")
		if vim.bo.modified then vim.cmd("write") end
	end,
	desc = "Autosave journal on change",
})