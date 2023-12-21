-- NeoVim Setting

-- Plugin
require('options')
require('plugins')
require('lsp')
require('coc')
require('comp')
require('keymap')
require('autocmds')
require('base')
require('tterm')
-- require('fff')
require('telefig')

vim.api.nvim_create_autocmd('BufWritePost', {
	pattern = { 'plugins.lua' },
	command = 'PackerCompile',
})

-- Japanese Input Source
require('im_select').setup {
    default_im_select = 'com.apple.keylayout.ABC'
}

-- NerdTree
vim.g.NERDTreeShowHidden = 1
vim.api.nvim_create_autocmd('VimEnter', {
	pattern = '*',
	callback = function()
		vim.cmd('NERDTree')
		vim.cmd('wincmd p')
	end,
})

-- View Setting
require('lualine').setup()
require('tabline').setup()

require('mini.indentscope').setup({
    symbol = '▏',
})

require('nvim-treesitter.configs').setup({
	auto_install = true,
	highlight = {
		enable = true,
	},
})

require('appearance')

-- after
vim.cmd('runtime! after/**/.vim')
