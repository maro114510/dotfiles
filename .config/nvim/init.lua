-- カラースキームの変更
vim.cmd[[colorscheme tokyonight-night]]

-- カーソルの設定→抜けるときに_
vim.cmd([[
    augroup RestoreCursorShapeOnExit
        autocmd!
        autocmd VimLeave * set guicursor=a:hor1
    augroup END
]])

-- クリップボードにコピーしない設定
vim.api.nvim_set_keymap('n', 'x', '"_x', {noremap = true})
vim.api.nvim_set_keymap('n', 's', '"_s', {noremap = true})
vim.api.nvim_set_keymap('n', 'd', '"_d', { noremap = true })
vim.api.nvim_set_keymap('n', 'D', '"_D', { noremap = true })
vim.api.nvim_set_keymap('x', 'd', '"_d', { noremap = true })

-- Esc
vim.api.nvim_set_keymap('i', 'jj', '<ESC>', {noremap = true, silent = true})

-- クリップボードにコピーしない ##要修正##
vim.opt.formatoptions:remove("r")
vim.opt.formatoptions:remove("o")

-- プラグイン
require("options")
require("plugins")

-- 日本語切り替え
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

-- いい感じの見た目
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

