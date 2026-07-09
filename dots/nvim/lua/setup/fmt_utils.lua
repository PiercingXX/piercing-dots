-- treesj
pcall(function()
  require('treesj').setup({})
end)

-- autopairs
pcall(function()
  local npairs = require('nvim-autopairs')
  npairs.setup({ enable_check_bracket_line = false })
end)

-- mini.surround
pcall(function()
  require('mini.surround').setup({
    custom_surroundings = nil,
    highlight_duration = 500,
    mappings = {
      add = 'sa',
      delete = 'sd',
      find = 'sf',
      find_left = 'sF',
      highlight = 'sh',
      replace = 'sr',
      update_n_lines = 'sn',
      suffix_last = 'l',
      suffix_next = 'n',
    },
    n_lines = 20,
    respect_selection_type = false,
    search_method = 'cover',
    silent = false,
  })
end)
