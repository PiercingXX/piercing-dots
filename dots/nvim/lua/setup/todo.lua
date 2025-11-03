---@diagnostic disable: undefined-global
pcall(function()
  local todo = require('floatingtodo')
  todo.setup({ target_file = '~/notes/todo.md', width = 0.9, position = 'center' })
end)

vim.keymap.set('n', '<leader>td', ':Td<CR>', { silent = true, desc = 'Floating TODO' })

-- Optional: zen-mode toggle
pcall(function()
  require('zen-mode').setup({ window = { width = 83 } })
end)
vim.keymap.set('n', '<leader>zz', ':ZenMode<CR>')
