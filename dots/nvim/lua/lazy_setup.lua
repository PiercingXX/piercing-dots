-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable",
        lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

-- Core options & keymaps reused from nightly config
require("config.options")
require("config.keymaps")
require("mappings.rust")
require("mappings.markdown")

local plugins = {
    { "goolord/alpha-nvim",        config = function() pcall(require, "setup.alpha") end },
    { "helbing/aura.nvim" },
    { "saghen/blink.cmp",          config = function() pcall(require, "setup.blink_cmp") end },
    { "akinsho/bufferline.nvim" },
    { "hat0uma/csvview.nvim",      config = function() pcall(require, "setup.csv") end },
    { "j-hui/fidget.nvim",         config = function() pcall(require, "setup.fidget") end },
    { "folke/flash.nvim",          config = function() pcall(require, "setup.flash") end },
    { "vimichael/floatingtodo.nvim", config = function() pcall(require, "setup.todo") end },
    { "rafamadriz/friendly-snippets" },
    { "ibhagwan/fzf-lua",          config = function() pcall(require, "setup.fzf") end },
    { "ellisonleao/glow.nvim",     config = function() pcall(require, "setup.glow") end },
    { "HakonHarnes/img-clip.nvim", config = function() pcall(require, "setup.img_clip") end },
    { "echasnovski/mini.icons" },
    { "echasnovski/mini.statusline", config = function() pcall(require, "setup.mini_statusline") end },
    { "echasnovski/mini.surround" },
    { "nvimtools/none-ls.nvim" },
    { "windwp/nvim-autopairs" },
    { "nvim-treesitter/nvim-treesitter", config = function() pcall(require, "setup.treesitter") end, build = ":TSUpdate" },
    { "nvim-treesitter/nvim-treesitter-textobjects" },
    { "windwp/nvim-ts-autotag" },
    { "nvim-tree/nvim-web-devicons", config = function() pcall(require, "setup.webdevicons") end },
    { "nvim-lua/plenary.nvim" },
    { "tris203/precognition.nvim", config = function() pcall(require, "setup.precognition") end },
    { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    { "nvim-telescope/telescope-ui-select.nvim" },
    { "jvgrootveld/telescope-zoxide" },
    { "nvim-telescope/telescope.nvim", config = function() pcall(require, "setup.telescope") end },
    { "Wansmer/treesj" },
    { "ThePrimeagen/vim-be-good" },
    { "tpope/vim-sleuth" },
    { "vimpostor/vim-tpipeline" },
    { "mg979/vim-visual-multi" },
    { "folke/which-key.nvim",      config = function() pcall(require, "setup.which_key") end },
    { "mikavilpas/yazi.nvim",      config = function() pcall(require, "setup.yazi") end },
    { "folke/zen-mode.nvim" },
    -- Optional: if twilight setup exists but plugin missing in lock, you can uncomment
    -- { "folke/twilight.nvim",       config = function() pcall(require, "setup.twilight") end },
}

require("lazy").setup(plugins, {
    ui = { border = "rounded" },
    change_detection = { notify = false },
})
