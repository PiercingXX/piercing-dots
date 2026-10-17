---@diagnostic disable: undefined-global
-- nvim-treesitter (main branch): installs parsers/queries only.
-- Highlighting is Neovim's own vim.treesitter.start(), enabled per FileType below.
local ok, ts = pcall(require, 'nvim-treesitter')
if not ok then return end

local languages = {
  "lua","sql","go","regex","bash","markdown","markdown_inline","yaml","json","cpp","csv","java","javascript","python","dockerfile","html","css","templ","php","promql","glsl",
  "vim","vimdoc","query",
}

-- Parser builds need the tree-sitter CLI (pacman -S tree-sitter-cli)
local has_cli = (vim.fn.executable('tree-sitter') == 1)

ts.setup({})

if has_cli then
  -- No-op for parsers that are already installed
  ts.install(languages)
else
  vim.schedule(function()
    vim.notify('treesitter: `tree-sitter` CLI not found; install tree-sitter-cli to build parsers', vim.log.levels.WARN)
  end)
end

-- Start treesitter highlighting for any buffer with a parser; auto-install missing ones
local function start(buf, lang)
  if vim.api.nvim_buf_is_valid(buf) and pcall(vim.treesitter.start, buf, lang) then
    vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  end
end

vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('TreesitterStart', { clear = true }),
  callback = function(ev)
    local lang = vim.treesitter.language.get_lang(ev.match)
    if not lang then return end
    if vim.treesitter.language.add(lang) then
      start(ev.buf, lang)
    elseif has_cli and vim.tbl_contains(ts.get_available(), lang) then
      ts.install(lang):await(function() start(ev.buf, lang) end)
    end
  end,
})

-- Incremental selection (built into Neovim: `an`/`in` in visual mode)
vim.keymap.set('n', 'gnn', 'van', { remap = true, desc = 'Start treesitter selection' })
vim.keymap.set('x', 'grn', 'an', { remap = true, desc = 'Expand treesitter selection' })
vim.keymap.set('x', 'grm', 'in', { remap = true, desc = 'Shrink treesitter selection' })

-- nvim-treesitter-textobjects (main branch)
pcall(function()
  require('nvim-treesitter-textobjects').setup({ select = { lookahead = true } })
  local select = require('nvim-treesitter-textobjects.select')
  local objects = {
    ['af'] = '@function.outer',
    ['if'] = '@function.inner',
    ['ac'] = '@class.outer',
    ['ic'] = '@class.inner',
  }
  for lhs, query in pairs(objects) do
    vim.keymap.set({ 'x', 'o' }, lhs, function()
      select.select_textobject(query, 'textobjects')
    end, { desc = 'Select ' .. query })
  end
end)

-- nvim-ts-autotag
pcall(function()
  require('nvim-ts-autotag').setup({
    opts = { enable_close = true, enable_rename = true, enable_close_on_slash = true },
  })
end)

-- Helper commands
pcall(function()
  -- Install/Update all configured parsers
  vim.api.nvim_create_user_command('TsEnsureAll', function()
    vim.notify('treesitter: ensuring parsers for ' .. #languages .. ' languages...')
    ts.install(languages, { summary = true }):await(function()
      vim.schedule(function()
        vim.notify('treesitter: installed parsers: ' .. table.concat(ts.get_installed(), ', '))
      end)
    end)
  end, { desc = 'Install/Update all configured Treesitter parsers' })

  -- List currently installed parsers
  vim.api.nvim_create_user_command('TsListInstalled', function()
    vim.notify('treesitter: installed parsers: ' .. table.concat(ts.get_installed(), ', '))
  end, { desc = 'List Treesitter installed parsers' })
end)
