-- clipboard copy setting
vim.api.nvim_set_keymap('n', 'x', '"_x', { noremap = true })
vim.api.nvim_set_keymap('n', 's', '"_s', { noremap = true })
vim.api.nvim_set_keymap('n', 'd', '"_d', { noremap = true })
vim.api.nvim_set_keymap('n', 'D', '"_D', { noremap = true })
vim.api.nvim_set_keymap('x', 'd', '"_d', { noremap = true })

-- Esc
vim.api.nvim_set_keymap('i', 'jj', '<ESC>', { noremap = true, silent = true })

-- Exchange ;:
vim.api.nvim_set_keymap('', ';',':', { noremap = true })

-- fzf
vim.keymap.set("n", "<c-P>",
  "<cmd>lua require('fzf-lua').files()<CR>", { silent = true }
)

vim.api.nvim_set_keymap('n', '<C-f>', ':FzfLua files<CR>', { noremap = true, silent = true })

-- COC
-- when normal mode
-- double space
vim.api.nvim_set_keymap('n', '<space><space>', '<Cmd>CocList<CR>', { noremap = true, silent = true })
-- space + hover = Hover
vim.api.nvim_set_keymap('n', '<space>h', '<Cmd>call CocAction("doHover")<CR>', { noremap = true, silent = true })
-- space + df = Definition
vim.api.nvim_set_keymap('n', '<space>df', '<Plug>(coc-definition)', { noremap = true, silent = true })
-- space + rf = References
vim.api.nvim_set_keymap('n', '<space>rf', '<Plug>(coc-references)', { noremap = true, silent = true })
-- space + rn = Rename
vim.api.nvim_set_keymap('n', '<space>rn', '<Plug>(coc-rename)', { noremap = true, silent = true })

-- word jump
vim.api.nvim_set_keymap('n', '<S-C-h>', "<cmd>lua require'hop'.hint_words()<cr>", {})

