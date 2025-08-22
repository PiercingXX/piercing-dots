return {
  "sidebar-nvim/sidebar.nvim",
  event = "BufReadPost",
  config = function()
    require("sidebar-nvim").setup({
      position = "left",
      width = 30,
      sections = { "buffers", "files", "diagnostics", "git" }, -- List of enabled sections

      buffers = {
        icon = "  ",
        sorting = "id",
        show_numbers = true,
        ignore_not_loaded = false,
        ignore_terminal = true,
        ignored_buffers = { "NvimTree_", "^fugitive", "vista" },
      },
      files = {
        icon = "  folder",
        show_hidden = true,
        ignore_patterns = { "%.git/", "node_modules/" },
      },
      -- Add other section configs here if needed
      
        -- You can define other built-in sections like `diagnostics`, `quickfix`, `loclist`, `gitsigns`, etc.
        -- Refer to sidebar.nvim documentation for the full list.

        -- Example of a custom section:
        -- my_custom_section = {
        --   title = "My Custom Section",
        --   layout = {
        --     {
        --       type = "paragraph",
        --       text = {
        --         "Hello from my custom section!",
        --         "This is some multiline text.",
        --       },
        --     },
        --   },
        -- },
    })
  end,
}