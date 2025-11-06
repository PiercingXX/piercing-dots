---@diagnostic disable: undefined-global
-- Multiple cursors setup using vim-visual-multi
-- Docs: :h visual-multi

-- Keymaps chosen to mimic VS Code: Alt+Shift+Down/Up and Alt+Shift+J/K
-- Note: Some terminals don't pass Alt+Shift+Arrow combos. We map both.
-- For Kitty/WezTerm/Alacritty you may need term-specific key passthrough.

-- Configure plugin variables (see g:VM_* in help)
vim.g.VM_default_mappings = 0
vim.g.VM_mouse_mappings = 1
vim.g.VM_maps = {
    -- Basic operations
    ["Find Under"] = "<C-d>", -- like VS Code: select next occurrence
    ["Skip Region"] = "<C-x>",
    ["Remove Region"] = "<C-z>",
}

local map = function(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, { noremap = true, silent = true, desc = desc })
end

-- Add cursor down/up (normal and visual)
-- vim-visual-multi exposes <Plug>(VM-Add-Cursor-Down) and Up
map({ 'n', 'v' }, '<A-S-Down>', '<Plug>(VM-Add-Cursor-Down)', 'MultiCursor add below')
map({ 'n', 'v' }, '<A-S-Up>',   '<Plug>(VM-Add-Cursor-Up)',   'MultiCursor add above')

-- Provide Alt+Shift+J/K as fallbacks (some terminals map these easily)
map({ 'n', 'v' }, '<A-S-j>', '<Plug>(VM-Add-Cursor-Down)', 'MultiCursor add below (J)')
map({ 'n', 'v' }, '<A-S-k>', '<Plug>(VM-Add-Cursor-Up)',   'MultiCursor add above (K)')

-- Optional: start multi-cursor with visual selection to lines
map('n', '<leader>ma', '<Plug>(VM-Select-All)', 'MultiCursor select all occurrences')
map('v', '<leader>ma', '<Plug>(VM-Visual-All)', 'MultiCursor visual: all occurrences')

-- Convenience: toggle multicursor help
map('n', '<leader>mh', ':VMMaps<CR>', 'MultiCursor: show mappings')
