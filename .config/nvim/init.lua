-- NeoVi Setting
-- Change Color Scheme
vim.cmd[[colorscheme tokyonight-night]]

-- when leave
vim.cmd([[
    augroup RestoreCursorShapeOnExit
        autocmd!
        autocmd VimLeave * set guicursor=a:hor1
    augroup END
]])

vim.cmd[[autocmd VimLeave * :!clear]]

-- clipboard copy setting
vim.api.nvim_set_keymap('n', 'x', '"_x', {noremap = true})
vim.api.nvim_set_keymap('n', 's', '"_s', {noremap = true})
vim.api.nvim_set_keymap('n', 'd', '"_d', { noremap = true })
vim.api.nvim_set_keymap('n', 'D', '"_D', { noremap = true })
vim.api.nvim_set_keymap('x', 'd', '"_d', { noremap = true })

-- Esc
vim.api.nvim_set_keymap('i', 'jj', '<ESC>', {noremap = true, silent = true})

-- Exchange ;:
vim.api.nvim_set_keymap('', ';',':', {noremap = true})

-- Indent
vim.o.smartindent = true
vim.o.list = true
vim.o.listchars = 'tab:>>-,trail:-'

-- Do not use clipboard
vim.opt.formatoptions:remove("r")
vim.opt.formatoptions:remove("o")

-- Plugin
require("options")
require("plugins")

-- Japanese Input Source
require('im_select').setup {
    default_im_select = "com.apple.keylayout.ABC"
}

-- NerdTree
vim.g.NERDTreeShowHidden = 1
vim.api.nvim_create_autocmd("VimEnter", {
  pattern = "*",
  callback = function()
    vim.cmd("NERDTree")
    vim.cmd("wincmd p")
  end,
})

-- View Setting
require("lualine").setup()
require("tabline").setup()

require("mini.indentscope").setup({
  symbol = "▏",
})

require("nvim-treesitter.configs").setup({
  auto_install = true,
  highlight = {
    enable = true,
  },
})

vim.cmd[[highlight Comment cterm=italic gui=italic guifg=#ffd700 ctermfg=226]]
