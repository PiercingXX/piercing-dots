---@diagnostic disable: undefined-global
-- Configure bash/sh LSP using new vim.lsp.config API (nvim-lspconfig >=0.11)
pcall(function()
  if vim.lsp.config then
    local cfg = vim.lsp.config('bashls', {})
    vim.api.nvim_create_autocmd('FileType', {
      pattern = { 'sh', 'bash' },
      callback = function(ev)
        if vim.lsp.get_active_clients({ bufnr = ev.buf, name = 'bashls' })[1] then return end
        vim.lsp.start(cfg)
      end,
    })
  else
    -- Fallback to legacy lspconfig if still present
    local ok, lspconfig = pcall(require, 'lspconfig')
    if ok and lspconfig.bashls then lspconfig.bashls.setup({}) end
  end
end)

-- null-ls successor for formatting & linting
pcall(function()
  local null_ls = require('null-ls')
  local sources = {}
  if null_ls and null_ls.builtins and null_ls.builtins.formatting and null_ls.builtins.formatting.shfmt then
    table.insert(sources, null_ls.builtins.formatting.shfmt.with({
      extra_args = { '-i', '2', '-ci' },
      condition = function() return vim.fn.executable('shfmt') == 1 end,
    }))
  end
  if null_ls and null_ls.builtins and null_ls.builtins.diagnostics and null_ls.builtins.diagnostics.shellcheck then
    table.insert(sources, null_ls.builtins.diagnostics.shellcheck.with({
      condition = function() return vim.fn.executable('shellcheck') == 1 end,
    }))
  end
  null_ls.setup({ sources = sources })
end)

-- :Format convenience
vim.keymap.set('n', '<leader>F', function() vim.lsp.buf.format({ async = true }) end, { desc = 'Format buffer' })
