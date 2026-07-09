---@diagnostic disable: undefined-global
local ok, lualine = pcall(require, 'lualine')
if not ok then return end

local function lsp_name()
  local buf_clients = vim.lsp.get_clients({ bufnr = 0 })
  if #buf_clients == 0 then return '' end
  local names = {}
  for _, c in ipairs(buf_clients) do
    table.insert(names, c.name)
  end
  return '  ' .. table.concat(names, ',')
end

lualine.setup({
  options = {
    theme = 'auto',
    icons_enabled = true,
    component_separators = { left = '│', right = '│' },
    section_separators = { left = '', right = '' },
    always_divide_middle = true,
    refresh = { statusline = 100, tabline = 200, winbar = 200 },
  },
  sections = {
    lualine_a = { 'mode' },
    lualine_b = { 'branch', 'diff', { 'diagnostics', sources = { 'nvim_diagnostic' } } },
    lualine_c = { { 'filename', path = 1, symbols = { modified = '●', readonly = '' } } },
    lualine_x = { lsp_name, 'encoding', 'fileformat', 'filetype' },
    lualine_y = { 'progress' },
    lualine_z = { 'location' },
  },

})
