-- Change Color Scheme
-- vim.cmd[[colorscheme tokyonight-night]]
-- nightfox, dayfox, dawnfox, duskfox, nordfox,terafox, carbonfox
vim.cmd([[colorscheme duskfox]])

-- when leave cursor setting
vim.cmd([[
	augroup RestoreCursorShapeOnExit
		autocmd!
		autocmd VimLeave * set guicursor=a:hor1
	augroup END
]])

vim.cmd([[highlight Normal ctermbg=NONE guibg=NONE]])
vim.cmd([[highlight Comment cterm=italic gui=italic guifg=#ffd700 ctermfg=226]])
