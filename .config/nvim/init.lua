-- NeoVim Setting

-- Plugin
require('load-plugin')

require('options')
require('plugins')
require('lsp')
require('coc')
require('comp')
require('keymap')
require('autocmds')
require('base')
require('tterm')
require('fzf-lua-setting')

require('appearance')

-- after
vim.cmd('runtime! after/**/.vim')
