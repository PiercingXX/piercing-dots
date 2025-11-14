local ok, precognition = pcall(require, 'precognition')
if not ok then return end

-- Default config aligned with plugin README
precognition.setup({
  startVisible = true,
  showBlankVirtLine = true,
  highlightColor = { link = 'Comment' },
  hints = {
    Caret = { text = '^', prio = 2 },
    Dollar = { text = '$', prio = 1 },
    MatchingPair = { text = '%', prio = 5 },
    Zero = { text = '0', prio = 1 },
    w = { text = 'w', prio = 10 },
    b = { text = 'b', prio = 9 },
    e = { text = 'e', prio = 8 },
    -- Uncomment to add more motions as desired
    -- W = { text = 'W', prio = 7 },
    -- B = { text = 'B', prio = 6 },
    -- E = { text = 'E', prio = 5 },
  },
  -- gutterHints = { G = { text = 'G', prio = 10 }, gg = { text = 'gg', prio = 9 } },
  -- disabled_fts = { 'startify' },
})

-- Keymaps to toggle/show/hide
---@diagnostic disable: undefined-global
vim.keymap.set('n', '<leader>mt', function() precognition.toggle() end, { desc = 'Precognition Toggle' })
vim.keymap.set('n', '<leader>mh', function() precognition.show() end, { desc = 'Precognition Show' })
vim.keymap.set('n', '<leader>mH', function() precognition.hide() end, { desc = 'Precognition Hide' })
