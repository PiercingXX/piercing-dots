---@diagnostic disable: undefined-global
pcall(function()
  local alpha = require('alpha')
  local dashboard = require('alpha.themes.dashboard')

  local function new_blank_document()
    local dir = vim.fn.expand('~/Documents')
    if vim.fn.isdirectory(dir) == 0 then
      vim.fn.mkdir(dir, 'p')
    end
    local filename = os.date('%Y-%m-%d_%H-%M-%S.md')
    local path = dir .. '/' .. filename
    vim.cmd.edit(path)
    vim.cmd.startinsert()
  end

  vim.api.nvim_create_user_command('NewDoc', new_blank_document, { desc = 'Create timestamped doc in ~/Documents' })

  dashboard.section.header.val = {
    [[   --------------------------------------------------- ]],
    [[     ░░░░█▀█░▀█▀░█▀▀░█▀▄░█▀▀░▀█▀░█▀█░█▀▀░█░█░█░█░░░░     ]],
    [[   ░░░░░░█▀▀░░█░░█▀▀░█▀▄░█░░░░█░░█░█░█░█░▄▀▄░▄▀▄░░░░░░ ]],
    [[     ░░░░▀░░░▀▀▀░▀▀▀░▀░▀░▀▀▀░▀▀▀░▀░▀░▀▀▀░▀░▀░▀░▀░░░░   ]],
    [[   xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx  ]],
    [[                                                        ]],
    [[                        +***#***==             .....    ]],
    [[                     *#%#%%%%%%%%###*+++*###@@@@%%@@    ]],
    [[                   #-%%%@@@@@@@@@@@@@@@:..-=*@@         ]],
    [[                 ....@@@@@-=%@@@@@@..:-=*%%             ]],
    [[                ....#@@@@@@@@@@@@.-==*@@#               ]],
    [[               =....@@@@@@@@@@@@@@@@@@@                  ]],
    [[               -:..@@@@@@@@@@@@@@@@@@%                   ]],
    [[              :-%::@@@@@@@@@@@@@@@@@@                    ]],
    [[             =---=%-+@@@@@@@@@@@@@@@                    ]],
    [[          %% +=--:..........+**#%*+                      ]],
    [[          @@ +-...........+-====--..                     ]],
    [[          @@=-:.......=@.............+                   ]],
    [[         %@@=......#@..................-                 ]],
    [[       . @@@==-::#@-.....................                ]],
    [[      @@@@@@@@%-%@.......................-               ]],
    [[     %@@@@@@@@@@#.........................+              ]],
    [[     @@@@@@@@@@@@+........................*              ]],
    [[     @@@@@@@@@@@@%........................#              ]],
    [[     #@@@@@@@@@@@.........................:=             ]],
    [[     =@@@@@@@@@@:..........................:             ]],
    [[    +=@@@@@@@@%............................#.:           ]],
    [[    ++@@@@@@@*-==-:........................@%:           ]],
    [[    #%@@@@@%%+++==-:.......................@%=           ]],
    [[    %@@@@@%@%#*+=--:.......................+@*=          ]],
    [[     @@@%%@@#*+==-::........................%%=          ]],
    [[     %@@@@@#*+==-::........................:#@-          ]],
    [[        @@#*+=--::.........................%@@+          ]],
    [[                                        ]],

  }

  dashboard.section.buttons.val = {
    dashboard.button('n', 'λ  > New doc', ':NewDoc<CR>'),
    dashboard.button('b', 'λ  > Browse files', ':Yazi<CR>'),
    dashboard.button('z', 'λ  > Browse Directories', ':Telescope zoxide list<CR>'),
    dashboard.button('f', 'λ  > Find file', ':Telescope find_files<CR>'),
    dashboard.button('r', 'λ  > Recent', ':Telescope oldfiles<CR>'),
  }

  alpha.setup(dashboard.opts)
end)
