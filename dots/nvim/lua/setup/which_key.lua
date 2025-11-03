---@diagnostic disable: undefined-global
local ok, wk = pcall(require, 'which-key')
if not ok then return end
wk.setup({})

vim.keymap.set('n', '<leader>?', function()
  require('which-key').show({ global = true })
end, { desc = 'Buffer Local Keymaps (which-key)' })
