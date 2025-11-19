---@diagnostic disable: undefined-global
local ok, ts = pcall(require, 'nvim-treesitter.configs')
if not ok then return end

-- Import ensure_installed list from existing plugin spec if possible
local languages = {
  "lua","sql","go","regex","bash","markdown","markdown_inline","latex","yaml","json","jsonc","cpp","csv","java","javascript","python","dockerfile","html","css","templ","php","promql","glsl",
}

-- Skip languages that require the tree-sitter CLI when it's not installed
local has_cli = (vim.fn.executable('tree-sitter') == 1)
if not has_cli then
  local filtered = {}
  for _, lang in ipairs(languages) do
    if lang ~= 'latex' then table.insert(filtered, lang) end
  end
  languages = filtered
  vim.schedule(function()
    vim.notify("treesitter: skipping latex (tree-sitter CLI not found)", vim.log.levels.WARN)
  end)
end

ts.setup({
  ensure_installed = languages,
  sync_install = false,
  auto_install = true,
  ignore_install = {},
  highlight = { enable = true, additional_vim_regex_highlighting = false },
  incremental_selection = {
    enable = true,
    keymaps = {
      init_selection = 'gnn',
      node_incremental = 'grn',
      scope_incremental = 'grc',
      node_decremental = 'grm',
    },
  },
  textobjects = {
    select = {
      enable = true,
      lookahead = true,
      keymaps = {
        ['af'] = '@function.outer',
        ['if'] = '@function.inner',
        ['ac'] = '@class.outer',
        ['ic'] = '@class.inner',
      },
    },
  },
})

-- nvim-ts-autotag
pcall(function()
  require('nvim-ts-autotag').setup({
    opts = { enable_close = true, enable_rename = true, enable_close_on_slash = true },
  })
end)

-- Helper commands
pcall(function()
  -- Install/Update all configured parsers (sync when possible)
  vim.api.nvim_create_user_command('TsEnsureAll', function()
    local cmd = (has_cli and 'TSInstallSync' or 'TSInstall') .. ' ' .. table.concat(languages, ' ')
    vim.notify('treesitter: ensuring parsers for ' .. #languages .. ' languages...')
    vim.cmd(cmd)
    local installed = {}
    local ok_install, install = pcall(require, 'nvim-treesitter.install')
    if ok_install and install.installed_parsers then
      installed = install.installed_parsers() or {}
    end
    vim.schedule(function()
      vim.notify('treesitter: installed parsers: ' .. table.concat(installed, ', '))
    end)
  end, { desc = 'Install/Update all configured Treesitter parsers' })

  -- List currently installed parsers
  vim.api.nvim_create_user_command('TsListInstalled', function()
    local ok_install, install = pcall(require, 'nvim-treesitter.install')
    if not ok_install or not install.installed_parsers then
      vim.notify('treesitter: could not query installed parsers', vim.log.levels.WARN)
      return
    end
    local installed = install.installed_parsers() or {}
    vim.notify('treesitter: installed parsers: ' .. table.concat(installed, ', '))
  end, { desc = 'List Treesitter installed parsers' })
end)
