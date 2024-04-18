-- clipboard copy setting
vim.api.nvim_set_keymap('n', 'x', '"_x', { noremap = true })
vim.api.nvim_set_keymap('n', 's', '"_s', { noremap = true })
vim.api.nvim_set_keymap('n', 'd', '"_d', { noremap = true })
vim.api.nvim_set_keymap('n', 'D', '"_D', { noremap = true })
vim.api.nvim_set_keymap('x', 'd', '"_d', { noremap = true })

vim.api.nvim_set_keymap('n', 'ciw', 'viw"_c', { noremap = true })

vim.api.nvim_set_keymap('n', 'ss', ':split<Return><C-w>w', {noremap = true})
vim.api.nvim_set_keymap('n', 'sv', ':vsplit<Return><C-w>w', {noremap = true})

-- change buffer files
vim.api.nvim_set_keymap('n', '<C-j>', '<cmd>bprev<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<C-k>', '<cmd>bnext<CR>', { noremap = true, silent = true })

-- move
vim.api.nvim_set_keymap('n', 'j', 'gj', { noremap = true })
vim.api.nvim_set_keymap('n', 'k', 'gk', { noremap = true })

-- yank
vim.api.nvim_set_keymap('n', 'Y', 'y$', { noremap = true })

-- Esc
vim.api.nvim_set_keymap('i', 'jj', '<ESC>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('i', 'っj', '<ESC>', { noremap = true, silent = true })

-- Exchange
vim.api.nvim_set_keymap('', ';',':', { noremap = true })

-- Telescope
vim.keymap.set(
	"n",
	"<C-f>",
	"<cmd>Telescope find_files find_command=rg,--files,--hidden,--glob,!*.git<cr>",
	{ noremap = true, silent = true }
)

vim.keymap.set(
	"n",
	"<C-P>",
	-- "<cmd>Telescope find_files find_command=rg,--files,--hidden,--glob,!*.git<cr>",
	"<cmd>Telescope smart_open<CR>",
	{ silent = true }
)
vim.api.nvim_set_keymap(
	'n',
	'<M-f>',
	'<cmd>Telescope lsp_dynamic_workspace_symbols find_command=rg,--files,--hidden,--glob,!*.git<cr>',
	-- '<cmd>lua require("fzf-lua").lsp_live_workspace_symbols()<CR>',
	{ noremap = true, silent = true }
)
vim.api.nvim_set_keymap(
	'n',
	'<C-g>',
	'<cmd>Telescope live_grep<cr>',
	{ noremap = true, silent = true }
)

-- ToggleTerm
vim.api.nvim_set_keymap(
	'n',
	'<C-T>',
	'<CMD>exe v:count1 . "ToggleTerm"<CR>',
	{ noremap = true, silent = true }
)

-- NeoTree
vim.api.nvim_set_keymap(
	"n",
	"<C-n>",
	"<CMD>Neotree<CR>",
	{ noremap = true, silent = true }
)

-- COC
-- when normal mode
-- double space
-- vim.api.nvim_set_keymap('n', '<space><space>', '<Cmd>CocList<CR>', { noremap = true, silent = true })
-- space + hwover = Hover
-- vim.api.nvim_set_keymap('n', '<space>h', '<Cmd>call CocAction("doHover")<CR>', { noremap = true, silent = true })
-- space + df = Definition
-- vim.api.nvim_set_keymap('n', '<space>df', '<Plug>(coc-definition)', { noremap = true, silent = true })
-- space + rf = References
-- vim.api.nvim_set_keymap('n', '<space>rf', '<Plug>(coc-references)', { noremap = true, silent = true })
-- space + rn = Rename
-- vim.api.nvim_set_keymap('n', '<space>rn', '<Plug>(coc-rename)', { noremap = true, silent = true })

