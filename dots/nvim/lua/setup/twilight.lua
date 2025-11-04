---@diagnostic disable: undefined-global
pcall(function()
  require('twilight').setup({})
  vim.keymap.set('n', '<leader>tw', ':Twilight<CR>', { desc = 'Toggle Twilight dim' })
end)
