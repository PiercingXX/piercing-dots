---@diagnostic disable: undefined-global
local ok, notify = pcall(require, "notify")
if not ok then return end

-- Use the current colorscheme (Aura) background so notifications match the theme
local function get_bg()
  local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false }) or {}
  if normal.bg then
    return string.format("#%06x", normal.bg)
  end
  return "#1a1b26" -- fallback dark tone if highlight missing
end

notify.setup({
  stages = "fade_in_slide_out",
  timeout = 2000,
  fps = 60,
  render = "default",
  top_down = true,
  background_colour = get_bg(),
})

vim.notify = notify

-- Optional: integrate with telescope if available
pcall(function()
  require("telescope").load_extension("notify")
end)

-- Convenience keymaps
-- Dismiss all notifications
vim.keymap.set("n", "<leader>un", function()
  require("notify").dismiss({ silent = true, pending = true })
end, { desc = "Dismiss notifications", silent = true })

-- Open notifications history
vim.keymap.set("n", "<leader>nn", ":Notifications<CR>", { desc = "Notifications history", silent = true })
