-- PiercingXX

-- File Navigation
vim.keymap.set('n', '<leader>z', '<cmd>Yazi cwd<CR>', {desc="Open Yazi CWD"})

-- Basic shit
vim.keymap.set('n', '<leader>w', ':write<CR>', {desc="Write"})
vim.keymap.set('n', '<leader>q', ':quit<CR>', {desc="Quit"})
vim.keymap.set('n', '<leader>o', ':update<CR> :source $HOME/.config/nvim/init.lua <CR>', {desc="Shoutout"})

-- yank to global clipboard
vim.keymap.set("v", "<leader>yg", '"+y')




-- Text Editing
-- create a new line with 2 spaces around it
vim.keymap.set("n", "<leader>tt", "o<Esc>o<Esc>o<Esc>k")




-- for moving around windows
vim.keymap.set("n", "<leader>h", "<C-W><C-H>")
vim.keymap.set("n", "<leader>j", "<C-W><C-J>")
vim.keymap.set("n", "<leader>k", "<C-W><C-K>")
vim.keymap.set("n", "<leader>l", "<C-W><C-L>")