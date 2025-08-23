return {
  "sidebar-nvim/sidebar.nvim",
  event = "VimEnter",          -- trigger on startup
  config = function()
    require("sidebar-nvim").setup({
      position = "left",
      width = 30,
      sections = { "buffers", "files", "diagnostics", "git" },

      buffers = {
        icon = "  ",
        sorting = "id",
        ignore_not_loaded = false,
        ignore_terminal = true,
        ignored_buffers = { "NvimTree_", "^fugitive", "vista" },
      },
      files = {
        icon = "  folder",
        show_hidden = true,
        ignore_patterns = { "%.git/", "node_modules/" },
      },
    })

    -- Force the sidebar to open immediately
    require("sidebar-nvim").open()

    -- Switch to the sidebar window (leftmost) and open Yazi in a terminal
    vim.cmd('wincmd h')          -- move to the leftmost window (the sidebar)
    vim.cmd('terminal yazi')     -- open Yazi inside that window
  end,
}