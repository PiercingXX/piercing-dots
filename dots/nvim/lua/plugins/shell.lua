---@diagnostic disable: undefined-global
return {
  -- Start bashls using the new Neovim LSP API for sh/bash files
  {
    "nvim-lua/plenary.nvim", -- dummy dependency to ensure this block is loaded
    config = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "sh", "bash" },
        callback = function()
          if vim.lsp.get_active_clients({ name = "bashls" })[1] then return end
          vim.lsp.start({ name = "bashls" })
        end,
      })
    end,
  },

  -- null-ls successor for formatting & linting
  {
    "nvimtools/none-ls.nvim",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local null_ls = require("null-ls")
      local sources = {}

      -- add shfmt if available
      if null_ls and null_ls.builtins and null_ls.builtins.formatting and null_ls.builtins.formatting.shfmt then
        table.insert(sources, null_ls.builtins.formatting.shfmt.with({
          extra_args = { "-i", "2", "-ci" },
          condition = function()
            return vim.fn.executable("shfmt") == 1
          end,
        }))
      end

      -- add shellcheck diagnostics if available
      if null_ls and null_ls.builtins and null_ls.builtins.diagnostics and null_ls.builtins.diagnostics.shellcheck then
        table.insert(sources, null_ls.builtins.diagnostics.shellcheck.with({
          condition = function()
            return vim.fn.executable("shellcheck") == 1
          end,
        }))
      end

      null_ls.setup({ sources = sources })
    end,
  },

  -- simple :Format keymap
  {
    "folke/which-key.nvim",
    opts = function(_, opts)
      -- add a helpful description for format key
      return opts
    end,
    keys = {
      { "<leader>F", function() vim.lsp.buf.format({ async = true }) end, desc = "Format buffer" },
    },
  },
}
