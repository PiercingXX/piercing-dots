pcall(function()
  require('glow').setup({ border = 'rounded', width_ratio = 0.9, height_ratio = 0.9 })
end)

---@diagnostic disable: undefined-global
vim.keymap.set('n', '<leader>mp', ':Glow<CR>', { desc = 'Markdown preview (Glow)' })
