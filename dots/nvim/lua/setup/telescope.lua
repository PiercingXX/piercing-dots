---@diagnostic disable: undefined-global
local ok, telescope = pcall(require, "telescope")
if not ok then return end

telescope.setup({
  defaults = {
    border = {
      prompt = { 1, 1, 1, 1 },
      results = { 1, 1, 1, 1 },
      preview = { 1, 1, 1, 1 },
    },
    borderchars = {
      prompt = { " ", " ", "─", "│", "│", " ", "─", "└" },
      results = { "─", " ", " ", "│", "┌", "─", " ", "│" },
      preview = { "─", "│", "─", "│", "┬", "┐", "┘", "┴" },
    },
  },
  extensions = {
    fzf = {
      fuzzy = true,
      override_generic_sorter = true,
      override_file_sorter = true,
      case_mode = "smart_case",
    },
    ["ui-select"] = require("telescope.themes").get_dropdown({}),
  },
  pickers = {
    colorscheme = { enable_preview = true },
    find_files = {
      hidden = true,
      find_command = {
        "rg",
        "--files",
        "--glob",
        "!" .. "{.git/*,.next/*,.svelte-kit/*,target/*,node_modules/*}",
        "--path-separator",
        "/",
      },
    },
  },
})

pcall(function() telescope.load_extension("fzf") end)
pcall(function() telescope.load_extension("zoxide") end)
pcall(function() telescope.load_extension("ui-select") end)

local builtin = require("telescope.builtin")
vim.keymap.set("n", "<leader>jk", function()
  builtin.find_files({ find_command = { "rg", "--files", "--hidden", "-g", "!.git" } })
end, { desc = "Find files (rg)" })
vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Find buffers" })
vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "Live grep" })
vim.keymap.set("n", "<leader>fd", builtin.diagnostics, { desc = "Diagnostics" })
vim.keymap.set("n", "<leader>ds", builtin.lsp_document_symbols, { desc = "Document symbols" })
vim.keymap.set("n", "<leader>ws", builtin.lsp_workspace_symbols, { desc = "Workspace symbols" })
vim.keymap.set("n", "<leader>fz", ":Telescope zoxide list<CR>", { desc = "Zoxide" })
vim.keymap.set("n", "<leader>fv", builtin.help_tags, { desc = "Help tags" })
