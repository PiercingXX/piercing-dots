---@diagnostic disable: undefined-global
local ok, csv = pcall(require, 'csvview')
if not ok then return end

csv.setup({
  parser = { comments = { '#', '//' } },
  keymaps = {
    textobject_field_inner = { 'if', mode = { 'o', 'x' } },
    textobject_field_outer = { 'af', mode = { 'o', 'x' } },
    jump_next_field_end = { '<Tab>', mode = { 'n', 'v' } },
    jump_prev_field_end = { '<S-Tab>', mode = { 'n', 'v' } },
    jump_next_row = { '<Enter>', mode = { 'n', 'v' } },
    jump_prev_row = { '<S-Enter>', mode = { 'n', 'v' } },
  },
})

-- Optional commands
vim.api.nvim_create_user_command('CsvOn', function() vim.cmd('CsvViewEnable') end, {})
vim.api.nvim_create_user_command('CsvOff', function() vim.cmd('CsvViewDisable') end, {})
