local utils = require('utils')

local function ensure_yazi_on_path()
  local path_sep = ':'
  local path_dirs = vim.split(vim.env.PATH or '', path_sep, { plain = true, trimempty = true })
  local preferred_dirs = {
    utils.expand_path('~/.cargo/bin'),
    utils.expand_path('~/.local/bin'),
    '/usr/local/bin',
    '/usr/bin',
    '/bin',
  }
  local discovered_dirs = {}
  local seen_dirs = {}

  local function add_dir(dir)
    if dir ~= '' and not seen_dirs[dir] then
      seen_dirs[dir] = true
      discovered_dirs[#discovered_dirs + 1] = dir
    end
  end

  for _, dir in ipairs(preferred_dirs) do
    if vim.fn.executable(dir .. '/yazi') == 1 or vim.fn.executable(dir .. '/ya') == 1 then
      add_dir(dir)
    end
  end

  for _, dir in ipairs(path_dirs) do
    add_dir(dir)
  end

  vim.env.PATH = table.concat(discovered_dirs, path_sep)
end

ensure_yazi_on_path()

pcall(function()
  require('yazi').setup({
    open_for_directories = false,
    keymaps = { show_help = '<f1>' },
  })
end)

---@diagnostic disable: undefined-global
vim.keymap.set('n', '<leader>-', '<cmd>Yazi<cr>', { desc = 'Open yazi at the current file' })
vim.keymap.set('n', '<leader>cw', '<cmd>Yazi cwd<cr>', { desc = "Open the file manager in nvim's working directory" })
vim.keymap.set('n', '<c-up>', '<cmd>Yazi toggle<cr>', { desc = 'Resume the last yazi session' })
