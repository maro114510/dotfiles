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
  "<cmd>lua require('fzf-lua').files()<CR>", { silent = true })

vim.api.nvim_set_keymap('n', '<C-f>', ':FzfLua files<CR>', { noremap = true, silent = true })

