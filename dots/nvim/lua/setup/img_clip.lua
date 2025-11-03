---@diagnostic disable: undefined-global
pcall(function()
  require('img-clip').setup({
    default = {
      use_absolute_path = false,
      relative_to_current_file = true,
      dir_path = vim.g.neovim_mode == 'skitty' and 'img' or function()
        return vim.fn.expand('%:t:r') .. '-img'
      end,
      prompt_for_file_name = false,
      file_name = '%y%m%d-%H%M%S',
      extension = 'avif',
      process_cmd = 'convert - -quality 75 avif:-',
    },
    filetypes = {
      markdown = {
        url_encode_path = true,
        template = vim.g.neovim_mode == 'skitty' and '![ ](./$FILE_PATH)' or '![Image](./$FILE_PATH)',
      },
    },
  })
end)
