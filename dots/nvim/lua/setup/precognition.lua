local ok, precognition = pcall(require, 'precognition')
if not ok then return end

-- Default config with some sensible tweaks; adjust to preference
precognition.setup({
  startVisible = true,          -- show hints automatically
  showBlankVirtLine = true,     -- keep layout stable
  highlightColor = 'Comment',   -- use a subtle highlight group
  hints = {                     -- enable common motions
    ['^'] = true,
    ['$'] = true,
    ['w'] = true,
    ['b'] = true,
    ['e'] = true,
    ['ge'] = true,
    ['f'] = true,
    ['t'] = true,
  },
})

-- Keymaps to toggle & cycle visibility
---@diagnostic disable: undefined-global
vim.keymap.set('n', '<leader>mt', function() precognition.toggle() end, { desc = 'Precognition Toggle' })
vim.keymap.set('n', '<leader>mh', function() precognition.enable() end, { desc = 'Precognition Show' })
vim.keymap.set('n', '<leader>mH', function() precognition.disable() end, { desc = 'Precognition Hide' })
