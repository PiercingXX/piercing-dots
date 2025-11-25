---@diagnostic disable: undefined-global
-- Robust bash/sh LSP setup that works across Neovim versions
pcall(function()
  -- Try Neovim's new LSP config API if present AND returns a valid config
  local cfg
  if type(vim.lsp.config) == 'function' then
    local ok_cfg, res = pcall(vim.lsp.config, 'bashls', {})
    if ok_cfg and res then cfg = res end
  end

  if cfg then
    -- Start on relevant filetypes only if not already attached
    vim.api.nvim_create_autocmd('FileType', {
      pattern = { 'sh', 'bash', 'zsh' },
      callback = function(ev)
        local clients = vim.lsp.get_clients({ bufnr = ev.buf, name = 'bashls' })
        if clients and #clients > 0 then return end
        vim.lsp.start(cfg)
      end,
    })
  else
    -- Fallback to lspconfig on older Neovim or when native cfg is unavailable
    local ok_lspc, lspconfig = pcall(require, 'lspconfig')
    if ok_lspc and lspconfig.bashls then
      lspconfig.bashls.setup({})
    end
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
