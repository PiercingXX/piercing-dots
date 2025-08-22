return {
    'windwp/nvim-autopairs',
    event = "InsertEnter",
    config = function()
        require('nvim-autopairs').setup()   -- explicit default setup
    end,
    -- or simply: config = true,  (but keep the comma!)
}