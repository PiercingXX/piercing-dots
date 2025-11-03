local ok, fzf = pcall(require, 'fzf-lua')
if not ok then return end

fzf.setup({
  keymap = {
    fzf = {
      ["ctrl-q"] = "select-all+accept",
      ["ctrl-u"] = "half-page-up",
      ["ctrl-d"] = "half-page-down",
      ["ctrl-x"] = "jump",
      ["ctrl-f"] = "preview-page-down",
      ["ctrl-b"] = "preview-page-up",
    },
    builtin = {
      ['<c-f>'] = 'preview-page-down',
      ['<c-b>'] = 'preview-page-up',
    },
  },
  oldfiles = { include_current_session = true },
  previewers = { builtin = { syntax_limit_b = 1024 * 100 } },
  grep = { rg_glob = true },
  combine = { pickers = 'oldfiles;git_files' },
})
