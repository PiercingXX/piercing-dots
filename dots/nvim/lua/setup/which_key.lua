---@diagnostic disable: undefined-global
local ok, wk = pcall(require, 'which-key')
if not ok then return end
wk.setup({
  plugins = { spelling = { enabled = false } },
  show_help = true,
})

-- Group labels for common leader prefixes
pcall(function()
  local groups_new = {
    { '<leader>d', group = 'diagnostics' },
    { '<leader>f', group = 'find' },
    { '<leader>m', group = 'motion' },
    { '<leader>t', group = 'tools' },
  }
  if wk.add then
    wk.add(groups_new)
  else
    -- Fallback to old style if running an older which-key version
    wk.register({
      ['<leader>d'] = { name = '+diagnostics' },
      ['<leader>f'] = { name = '+find' },
      ['<leader>m'] = { name = '+motion' },
      ['<leader>t'] = { name = '+tools' },
    })
  end
end)

vim.keymap.set('n', '<leader>?', function()
  wk.show({ global = true })
end, { desc = 'Show all keymaps (which-key)' })
