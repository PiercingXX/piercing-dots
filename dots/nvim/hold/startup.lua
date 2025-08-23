return {
    "startup-nvim/startup.nvim",
    event = "VimEnter",
    priority = 1000,
    dependencies = {
        "nvim-telescope/telescope.nvim",
        "nvim-lua/plenary.nvim",
        "nvim-telescope/telescope-file-browser.nvim",
    },

    opts = {
        section_1 = {
            header ={
                "        ==========================================================================================          ",
                "     ||   /$$$$$$$  /$$                               /$$                     /$$   /$$ /$$   /$$    ||     ",
                "     ||  | $$__$  $$|__/                              |__/                    | $$  / $$| $$  / $$   ||     ",
                "     ||  | $$    $$ /$$  /$$$$$$   /$$$$$$   /$$$$$$$ /$$ /$$$$$$$   /$$$$$$ |  $$/ $$/|  $$/ $$/    ||     ",
                "     ||  | $$$$$$$/| $$ /$$__  $$ /$$__  $$ /$$_____/| $$| $$__  $$ /$$__  $$    $$$$/     $$$$/     ||     ",
                "     ||  | $$____/ | $$| $$$$$$$$| $$   __/| $$      | $$| $$    $$| $$    $$  >$$  $$   >$$  $$     ||     ",
                "     ||  | $$      | $$| $$_____/| $$      | $$      | $$| $$  | $$| $$  | $$ /$$/   $$ /$$/   $$    ||     ",
                "     ||  | $$      | $$|  $$$$$$$| $$      |  $$$$$$$| $$| $$  | $$|  $$$$$$$| $$    $$| $$    $$    ||     ",
                "     ||  |__/      |__/  _______/|__/        _______/|__/|__/  |__/  ____  $$|__/  |__/|__/  |__/    ||     ",
                "     ||                                                             /$$    $$                        ||     ",
                "     ||                                                            |  $$$$$$/                        ||     ",
                "     ||                                                              ______/                         ||     ",
                "        ==========================================================================================          ",
            },
            commands = {
                { desc = "Open File",   action = "Yazi" },
                { desc = "Open FzF",    action = 'yazi -c "fzf"' },
                { desc = "Preview FzF", action = "yazi -c \"fzf --preview 'bat {}'\"" },
                { desc = "Open Neo-Tree", action = "neotree show" },
                { desc = "Search Text", action = "Telescope live_grep" },
                { desc = "Open Config", action = "edit ~/.config/nvim/init.lua" },
            },
        },
        section_2 = {
            header = "Recent Files",
            commands = {
                { desc = "Recent Files", action = "Telescope oldfiles" },
                { desc = "Open Projects", action = "Telescope projects" },
            },
        },
        options = {
            mapping_keys  = true,
            cursor_column = 0.5,
            after = function()
                print("Startup complete!")
            end,
        },
        mappings = {
            execute_command = "<CR>",
            open_file       = "o",
            open_file_split = "<c-o>",
            open_section    = "<TAB>",
            open_help       = "?",
        },
        colors = {
            background     = "#1f2227",
            folded_section = "#56b6c2",
        },
        parts = { "section_1", "section_2" },

        -- <‑‑ NEW: center the header text horizontally
        center = true,
    },

    config = function(_, opts)
        require("startup").setup(opts)   -- <‑‑ launch the startup screen
    end,
}