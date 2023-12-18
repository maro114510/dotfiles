vim.api.nvim_set_keymap('n', '<leader>to', [[:lua require's:TabOpenFunc'()<CR>]], { noremap = true, silent = true })
vim.cmd([[command! -nargs=0 FZFTabOpen lua require's:TabOpenFunc'()]])

function _G.TabOpenFunc()
    local tab_list = vim.fn.execute('tabs')
    local text_list = {}

    for _, tab_text in ipairs(vim.fn.split(tab_list, '\n')) do
        local tab_page_text = string.match(tab_text, '^Tab page')
        if not tab_page_text then
            local page_num = string.match(tab_text, '[0-9]*$')
            table.insert(text_list, string.format('%d %s', page_num, tab_text))
        end
    end

    local result = vim.fn['fzf#run']({
        source = text_list,
        sink = function(line) _G.TabListSink(line) end,
        options = '-m -x +s',
        down = '40%',
    })

    if result then
        vim.cmd('normal ' .. vim.fn.split(result, ' ')[1] .. 'gt')
    end
end

function _G.TabListSink(line)
    local parts = vim.fn.split(line, '%s')
    vim.cmd('normal ' .. parts[1] .. 'gt')
end

