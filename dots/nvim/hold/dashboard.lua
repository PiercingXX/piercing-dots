return {
  -- This spec makes dashboard.nvim the default dashboard in LazyVim
  {
    "nvimdev/dashboard-nvim",
    event = "VimEnter", -- Load on Neovim startup
    dependencies = { "nvim-tree/nvim-web-devicons", "mikavilpas/yazi.nvim" }, -- Dependency for icons and yazi.nvim
    opts = function(_, opts)
      opts.config = {
        -- Header section (optional)
        header = {

          "        ==========================================================================================        ",
          "     ||   /$$$$$$$  /$$                               /$$                     /$$   /$$ /$$   /$$  ||     ",
          "     ||  | $$__  $$|__/                              |__/                    | $$  / $$| $$  / $$  ||     ",
          "     ||  | $$    $$ /$$  /$$$$$$   /$$$$$$   /$$$$$$$ /$$ /$$$$$$$   /$$$$$$ |  $$/ $$/|  $$/ $$/  ||     ",
          "     ||  | $$$$$$$/| $$ /$$__  $$ /$$__  $$ /$$_____/| $$| $$__  $$ /$$__  $$    $$$$/     $$$$/   ||     ",
          "     ||  | $$____/ | $$| $$$$$$$$| $$   __/| $$      | $$| $$    $$| $$    $$  >$$  $$   >$$  $$   ||     ",
          "     ||  | $$      | $$| $$_____/| $$      | $$      | $$| $$  | $$| $$  | $$ /$$/   $$ /$$/   $$  ||     ",
          "     ||  | $$      | $$|  $$$$$$$| $$      |  $$$$$$$| $$| $$  | $$|  $$$$$$$| $$    $$| $$    $$  ||     ",
          "     ||  |__/      |__/  _______/|__/        _______/|__/|__/  |__/  ____  $$|__/  |__/|__/  |__/  ||     ",
          "     ||                                                             /$$    $$                      ||     ",
          "     ||                                                            |  $$$$$$/                      ||     ",
          "     ||                                                              ______/                       ||     ",
          "        ==========================================================================================        ",

        },

        -- Custom commands in the center section
        center = {
          {
            action = "Telescope oldfiles",
            desc = " Recent Files",
            icon = " ",
            key = "r",
          },
          {
            action = "Telescope projects",
            desc = " Projects",
            icon = " ",
            key = "p",
          },
          {
            action = "LazyExtras",
            desc = " Lazy Extras",
            icon = " ",
            key = "x",
          },
          {
            action = "Lazy",
            desc = " Lazy",
            icon = "   ",
            key = "l",
          },
          {
            action = "Yazi", -- This will open Yazi in a floating window
            desc = " Open Yazi",
            icon = "   ", -- Example Yazi icon (you might need a Nerd Font)
            key = "y",
          },
          {
            action = "qa",
            desc = " Quit",
            icon = " ",
            key = "q",
          },
        },

        -- Other options for dashboard-nvim
        theme = "hyper", -- Or "doom"
        disable_move = false,
        change_to_vcs_root = false,
        -- You can explore more options in the dashboard.nvim documentation
        -- Example of a custom section at the bottom (optional)
        -- footer = {
        --   "                                                    ",
        --   "        Powered by LazyVim.                          ",
        --   "                                                    ",
        -- },
      }
    end,
  },
}

