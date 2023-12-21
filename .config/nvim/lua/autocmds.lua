-- packer 
vim.api.nvim_create_autocmd('BufWritePost', {
	pattern = { 'plugins.lua' },
	command = 'PackerCompile',
})

-- NerdTree
vim.api.nvim_create_autocmd('VimEnter', {
	callback = function()
		vim.cmd('NERDTree')
		vim.cmd('wincmd p')
	end,
})

-- Change Color Scheme
vim.cmd[[colorscheme tokyonight-night]]

-- when leave
vim.cmd([[
	augroup RestoreCursorShapeOnExit
		autocmd!
		autocmd VimLeave * set guicursor=a:hor1
	augroup END
]])

vim.cmd[[highlight Comment cterm=italic gui=italic guifg=#ffd700 ctermfg=226]]
