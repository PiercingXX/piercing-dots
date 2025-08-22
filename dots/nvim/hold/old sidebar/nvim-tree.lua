return {
  "nvim-tree/nvim-tree.lua",
  dependencies = {
    "nvim-tree/nvim-web-devicons", -- Required for file icons
  },
  config = function()
    -- Disable netrw (built-in file explorer)
    vim.g.loaded_netrw = 1
    vim.g.loaded_netrwPlugin = 1

    require("nvim-tree").setup({
      -- Custom settings go here
      view = {
        width = 30, -- Adjust the width of the nvim-tree window
      },
      filters = {
        dotfiles = true, -- Show hidden files
        git_ignored = false, -- Include git-ignored files
      },
      git = {
        enable = true, -- Show git status in the file tree
      },
      diagnostics = {
        enable = true,
      },
      disable_netrw = true,
      hijack_netrw = true,
      on_attach = function(bufnr)
        local api = require "nvim-tree.api"
        local function opts(desc)
          return { desc = "nvim-tree: " .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
        end

        -- Default mappings
        api.config.mappings.default_on_attach(bufnr)

        -- Custom mappings
        vim.keymap.set('n', '<leader>n', api.tree.toggle, opts("Toggle nvim-tree")) -- Toggle with <leader>n
        vim.keymap.set('n', '<leader>f', api.tree.toggle_focus, opts("Focus/unfocus nvim-tree"))
        vim.keymap.set('n', '<leader>r', api.tree.reload, opts("Refresh nvim-tree"))
      end,
    })
  end,
}

