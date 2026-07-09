---@diagnostic disable: undefined-global
-- Configure bash/sh LSP using vim.lsp.start with manual config
pcall(function()
  local root_dir = require('vim.lsp.util').find_git_ancestor(vim.api.nvim_buf_get_name(0))
  
  vim.api.nvim_create_autocmd('FileType', {
    pattern = { 'sh', 'bash' },
    callback = function(ev)
      -- Check if bashls is already running for this buffer
      local clients = vim.lsp.get_clients({ bufnr = ev.buf, name = 'bashls' })
      if clients and #clients > 0 then return end
      
      vim.lsp.start({
        name = 'bashls',
        cmd = { 'bash-language-server', 'start' },
        root_dir = root_dir or vim.fn.getcwd(),
      })
    end,
  })
end)

-- null-ls successor for formatting & linting
pcall(function()
  local null_ls = require('null-ls')
  local sources = {}
  
  -- Add shfmt if available
  pcall(function()
    if null_ls.builtins.formatting.shfmt and vim.fn.executable('shfmt') == 1 then
      table.insert(sources, null_ls.builtins.formatting.shfmt.with({
        extra_args = { '-i', '2', '-ci' },
      }))
    end
  end)
  
  if #sources > 0 then
    null_ls.setup({ sources = sources })
  end
end)

-- :Format convenience
vim.keymap.set('n', '<leader>F', function() vim.lsp.buf.format({ async = true }) end, { desc = 'Format buffer' })
