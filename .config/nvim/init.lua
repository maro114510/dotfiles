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

-- Japanese Input Source
require('im_select').setup {
    default_im_select = 'com.apple.keylayout.ABC'
}

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
