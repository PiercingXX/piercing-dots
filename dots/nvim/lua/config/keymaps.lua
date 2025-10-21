-- PiercingXX


-- File Navigation
-- Open Yazi in the directory of the current file, or CWD if no file
    vim.keymap.set('n', '<leader>z', function()
        local file = vim.api.nvim_buf_get_name(0)
        local dir = (file ~= '' and ((vim.fs and vim.fs.dirname and vim.fs.dirname(file)) or vim.fn.fnamemodify(file, ':p:h')))
                or vim.fn.getcwd(0)
        require('yazi').yazi({ cwd = dir })
    end, { desc = 'Open Yazi in file dir', silent = true })
-- Open Yazi in a new tab in the directory of the current file, or CWD if no file
    vim.keymap.set('n', '<leader>Z', function()
        local dir = vim.fn.getcwd(0)
        vim.cmd('tabnew')
        vim.cmd('tcd ' .. vim.fn.fnameescape(dir))
        require('yazi').yazi({})
    end, { desc = 'Open Yazi in new tab at window CWD', silent = true })



-- Cycle tabs
    vim.keymap.set('n', '<leader>L', '<Cmd>tabnext<CR>', { silent = true, desc = 'Next tab' })
    vim.keymap.set('n', '<leader>H',  '<Cmd>tabprevious<CR>', { silent = true, desc = 'Prev tab' })





-- Basic shit
    vim.keymap.set('n', '<leader>w', ':write<CR>', {desc="Write"})
    vim.keymap.set('n', '<leader>q', ':quit<CR>', {desc="Quit"})
    vim.keymap.set('n', '<leader>o', ':update<CR> :source $HOME/.config/nvim/init.lua <CR>', {desc="Shoutout"})



-- yank to global clipboard
    vim.keymap.set("v", "<leader>yg", '"+y')



-- autocomplete in normal text
    vim.keymap.set("i", "<C-f>", "<C-x><C-f>", { noremap = true, silent = true })
    vim.keymap.set("i", "<C-n>", "<C-x><C-n>", { noremap = true, silent = true })
    vim.keymap.set("i", "<C-l>", "<C-x><C-l>", { noremap = true, silent = true })


-- Spell check toggle
    vim.keymap.set('n', '<leader>ll', function()
        vim.opt_local.spell = not vim.opt_local.spell:get()
        vim.opt_local.spelllang = 'en_us'
    end, { desc = 'Toggle spell', silent = true })


-- see error
    vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float)


-- go to errors
    vim.keymap.set("n", "[e", vim.diagnostic.goto_next)
    vim.keymap.set("n", "]e", vim.diagnostic.goto_next)




-- Journal/Notes Keymaps
    -- Journal/Note in a new tab
    vim.keymap.set('n', '<leader>n', function()
        local note_dir = vim.fn.expand('/media/Archived-Storage/[03] Other/My Life/02 Journal')
        local date = os.date('%Y-%m-%d')
        local note_file = note_dir .. '/' .. date .. '.md'
        if vim.fn.filereadable(note_file) == 0 then
            vim.fn.mkdir(note_dir, 'p')
            vim.fn.writefile({ '# Journal for ' .. date, '' }, note_file)
        end
        vim.cmd('tabnew ' .. vim.fn.fnameescape(note_file))
    end, { desc = "Open today's journal in new tab", silent = true })

-- Note Formatting
    vim.keymap.set('n', '<C-t>', function()
        local time = os.date('%H:%M:%S')
        vim.api.nvim_put({ '', '  ' .. time .. '  ', '' }, 'l', true, true)
    end, { desc = 'Insert current time', silent = true })

    vim.keymap.set('i', '<C-t>', function()
        local time = os.date('%H:%M:%S')
        vim.api.nvim_put({ '', '  ' .. time .. '  ', '' }, 'l', true, true)
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'n', true)
    end, { desc = 'Insert current time (insert mode)', silent = true })