---@diagnostic disable: undefined-global
-- Neovim built-in plugin manager bootstrap using vim.pack

local function gh(repo)
  return string.format("https://github.com/%s", repo)
end

-- List of plugin specs
local specs = {
  -- UI and aesthetics
  { src = gh("helbing/aura.nvim") },
  { src = gh("goolord/alpha-nvim") },

  -- Completion & snippets
  { src = gh("saghen/blink.cmp"), version = "1.*" },
  { src = gh("rafamadriz/friendly-snippets") },

  -- Statusline & small utilities
  { src = gh("echasnovski/mini.statusline") },
  { src = gh("echasnovski/mini.surround") },
  { src = gh("echasnovski/mini.icons") },
  { src = gh("j-hui/fidget.nvim") },

  -- Treesitter and related
  { src = gh("nvim-treesitter/nvim-treesitter") },
  { src = gh("nvim-treesitter/nvim-treesitter-textobjects") },
  { src = gh("windwp/nvim-ts-autotag") },

  -- Telescope and friends
  { src = gh("nvim-lua/plenary.nvim") },
  { src = gh("nvim-telescope/telescope.nvim"), version = "0.1.8" },
  { src = gh("nvim-telescope/telescope-fzf-native.nvim") },
  { src = gh("jvgrootveld/telescope-zoxide") },
  { src = gh("nvim-telescope/telescope-ui-select.nvim") },

  -- FZF alternative
  { src = gh("ibhagwan/fzf-lua") },

  -- Files, icons, bufferline
  { src = gh("nvim-tree/nvim-web-devicons") },
  { src = gh("akinsho/bufferline.nvim") },

  -- Markdown, images, preview
  { src = gh("ellisonleao/glow.nvim") },
  { src = gh("HakonHarnes/img-clip.nvim") },

  -- CSV
  { src = gh("hat0uma/csvview.nvim") },

  -- Motions & navigation
  { src = gh("folke/flash.nvim") },
  { src = gh("folke/which-key.nvim") },
  { src = gh("tris203/precognition.nvim") }, -- motion hints & practice

  -- Editing helpers
  { src = gh("Wansmer/treesj") },
  { src = gh("windwp/nvim-autopairs") },
  { src = gh("mg979/vim-visual-multi") },

  -- Lint/format
  { src = gh("nvimtools/none-ls.nvim") },
  -- LSP config
  { src = gh("neovim/nvim-lspconfig") },

  -- Misc
  { src = gh("tpope/vim-sleuth") },
  { src = gh("vimpostor/vim-tpipeline") },
  { src = gh("mikavilpas/yazi.nvim") },
  { src = gh("vimichael/floatingtodo.nvim") },
  { src = gh("folke/zen-mode.nvim") },
  { src = gh("ThePrimeagen/vim-be-good") }, -- motion training game
}

-- Ensure plugins are installed and loaded
vim.pack.add(specs, { load = true, confirm = false })

-- Build hooks for plugins that need compilation
vim.api.nvim_create_autocmd({ "PackChanged" }, {
  callback = function(ev)
    local name, kind = ev.data.spec.name, ev.data.kind
    if name == "telescope-fzf-native.nvim" and (kind == "install" or kind == "update") then
      vim.system({ "make" }, { cwd = ev.data.path }, function() end)
    end
  end,
})

-- Configure plugins (requires after loading)
local function safe_require(mod)
  local ok, m = pcall(require, mod)
  if not ok then return nil end
  return m
end

-- Icons and devicons early
safe_require("setup.webdevicons")
safe_require("setup.mini_icons")

-- Try to apply the Aura colorscheme if available
pcall(function()
  vim.cmd.colorscheme('aura')
end)

-- Core setups
safe_require("setup.treesitter")
safe_require("setup.telescope")
safe_require("setup.fzf")
safe_require("setup.which_key")
safe_require("setup.flash")
safe_require("setup.precognition")
safe_require("setup.fidget")
safe_require("setup.csv")
safe_require("setup.fmt_utils")
safe_require("setup.mini_statusline")
safe_require("setup.img_clip")
safe_require("setup.glow")
safe_require("setup.yazi")
safe_require("setup.shell")
safe_require("setup.todo")
safe_require("setup.blink_cmp")
safe_require("setup.alpha")
safe_require("setup.multicursor")
