return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-tree/nvim-web-devicons",
      "nvim-telescope/telescope.nvim", -- added telescope dependency
    },
    lazy = false,
    config = function()
      require("neo-tree").setup({
        close_if_last_window = true,
        popup_border_style   = "rounded",
        source_selector = {
          winbar = false,
          statusline = false,
          position = "left",
          style = "default",
        },
        window = {
          width = 33,
          mappings = {
            ["<CR>"] = "open",
            ["<C-]"] = "close_node",
            ["<C-\\>"] = "toggle_node",
          },
        },
        filesystem = {
          filtered_items = { hide_dotfiles = false, hide_gitignored = true },
          follow_current_file = true,
          use_libuv_file_watcher = true,
        },
        sources = { "filesystem" },
        default_component_configs = {
          icon = {
            folder_closed = "",
            folder_open   = "",
            folder_empty  = "",
            default       = "",
          },
        },
      })
      vim.api.nvim_create_autocmd("VimEnter", {
        callback = function()
          vim.cmd("Neotree")
          vim.cmd("wincmd s")
          local h = math.floor(vim.o.lines * 0.30)
          vim.cmd("resize " .. h)
          vim.cmd("Terminal Yazi")
        end,
      })
    end,
  },
}