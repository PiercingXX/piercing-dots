---@diagnostic disable: undefined-global
local ok, telescope = pcall(require, 'telescope')
if not ok then return end

telescope.setup({
  defaults = {
    border = {
      prompt = { 1, 1, 1, 1 },
      results = { 1, 1, 1, 1 },
      preview = { 1, 1, 1, 1 },
    },
    borderchars = {
      prompt = { ' ', ' ', '─', '│', '│', ' ', '─', '└' },
      results = { '─', ' ', ' ', '│', '┌', '─', ' ', '│' },
      preview = { '─', '│', '─', '│', '┬', '┐', '┘', '┴' },
    },
  },
  extensions = {
    fzf = {
      fuzzy = true,
      override_generic_sorter = true,
      override_file_sorter = true,
      case_mode = 'smart_case',
    },
    ['ui-select'] = require('telescope.themes').get_dropdown({}),
  },
  pickers = {
    colorscheme = { enable_preview = true },
    find_files = {
      hidden = true,
      find_command = { 'rg', '--files', '--glob', '!' .. '{.git/*,.next/*,.svelte-kit/*,target/*,node_modules/*}', '--path-separator', '/' },
    },
  },
})

pcall(function() telescope.load_extension('fzf') end)
pcall(function() telescope.load_extension('zoxide') end)
pcall(function() telescope.load_extension('ui-select') end)

local builtin = require('telescope.builtin')
vim.keymap.set('n', '<leader>jk', "<cmd>lua require'telescope.builtin'.find_files({ find_command = {'rg', '--files', '--hidden', '-g', '!.git' }})<cr>")
vim.keymap.set('n', '<leader>fb', ':Telescope file_browser<cr>')
vim.keymap.set('n', '<leader>fg', builtin.live_grep)
vim.keymap.set('n', '<leader>fd', builtin.diagnostics)
vim.keymap.set('n', '<leader>ds', builtin.lsp_document_symbols)
vim.keymap.set('n', '<leader>ws', builtin.lsp_workspace_symbols)
vim.keymap.set('n', '<leader>fz', ':Telescope zoxide list<CR>')
vim.keymap.set('n', '<leader>fv', builtin.help_tags)
