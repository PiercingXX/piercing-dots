---@diagnostic disable: undefined-global
local ok, wk = pcall(require, 'which-key')
if not ok then return end
wk.setup({
  plugins = { spelling = { enabled = false } },
  show_help = true,
})

-- Group labels for common leader prefixes
pcall(function()
  wk.register({
    ['<leader>m'] = { name = '+motion' },
    ['<leader>f'] = { name = '+find' },
    ['<leader>t'] = { name = '+tools' },
    ['<leader>d'] = { name = '+diagnostics' },
  })
end)

vim.keymap.set('n', '<leader>?', function()
  wk.show({ global = true })
end, { desc = 'Show all keymaps (which-key)' })
