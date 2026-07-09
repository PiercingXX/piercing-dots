---@diagnostic disable: undefined-global
pcall(function()
  require('headlines').setup({
    markdown = {
      fat_headlines = false,
      bullets = { '•', '◦', '▪' },
    },
  })
end)
