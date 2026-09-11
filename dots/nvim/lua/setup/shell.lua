---@diagnostic disable: undefined-global
-- Bash/sh LSP + null-ls formatting

if vim.fn.executable("bash-language-server") == 1 then
  local ok, err = pcall(function()
    require("lspconfig").bashls.setup({
      filetypes = { "sh", "bash" },
      root_dir = function(fname)
        return vim.fs.root(fname, { ".git" }) or vim.fn.getcwd()
      end,
    })
  end)
  if not ok then
    vim.schedule(function()
      vim.notify("bashls setup failed: " .. tostring(err), vim.log.levels.WARN)
    end)
  end
end

-- null-ls successor for formatting & linting
pcall(function()
  local null_ls = require("null-ls")
  local sources = {}

  if null_ls.builtins.formatting.shfmt and vim.fn.executable("shfmt") == 1 then
    table.insert(sources, null_ls.builtins.formatting.shfmt.with({
      extra_args = { "-i", "2", "-ci" },
    }))
  end

  if #sources > 0 then
    null_ls.setup({ sources = sources })
  end
end)

vim.keymap.set("n", "<leader>F", function()
  vim.lsp.buf.format({ async = true })
end, { desc = "Format buffer" })
