return {
  -- fzf-lua plugin configuration
  {
    "ibhagwan/fzf-lua",
    opts = {
      -- Customize keybindings for fzf-lua pickers
      keymap = {
        -- Quickfix list actions
        fzf = {
          ["ctrl-q"] = "select-all+accept",
          ["ctrl-u"] = "half-page-up",
          ["ctrl-d"] = "half-page-down",
          ["ctrl-x"] = "jump",
          ["ctrl-f"] = "preview-page-down",
          ["ctrl-b"] = "preview-page-up",
        },
        -- Built-in actions
        builtin = {
          ["<c-f>"] = "preview-page-down",
          ["<c-b>"] = "preview-page-up",
        },
      },
      -- Customizations for the oldfiles picker
      oldfiles = {
        -- Include buffers visited in the current session
        include_current_session = true,
      },
      -- Preview window options
      previewers = {
        builtin = {
          -- Disable syntax highlighting for large files (100KB in this example) to improve performance
          syntax_limit_b = 1024 * 100,
        },
      },
      -- Grep configuration
      grep = {
        -- Enable `rg` globbing for filtering results by filename
        rg_glob = true,
      },
      -- Example of combining pickers (oldfiles and git_files)
      -- You can use this with `:FzfLua combine pickers=oldfiles;git_files`
      combine = {
        pickers = "oldfiles;git_files",
      },
      -- You can add other customizations here, refer to fzf-lua documentation
    },
  },
}

