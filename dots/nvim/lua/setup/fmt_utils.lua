-- treesj
pcall(function()
  require("treesj").setup({})
end)

-- autopairs
pcall(function()
  local npairs = require("nvim-autopairs")
  npairs.setup({ enable_check_bracket_line = false })
end)

-- mini.surround — use gz* so Flash can keep `s`
pcall(function()
  require("mini.surround").setup({
    custom_surroundings = nil,
    highlight_duration = 500,
    mappings = {
      add = "gza",
      delete = "gzd",
      find = "gzf",
      find_left = "gzF",
      highlight = "gzh",
      replace = "gzr",
      update_n_lines = "gzn",
      suffix_last = "l",
      suffix_next = "n",
    },
    n_lines = 20,
    respect_selection_type = false,
    search_method = "cover",
    silent = false,
  })
end)
