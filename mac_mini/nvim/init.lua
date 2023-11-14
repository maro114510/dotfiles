vim.cmd([[
  let &t_SI = "\<Esc>[5 q"
  let &t_EI = "\<Esc>[2 q"
  autocmd VimLeave * let &t_me = "\<Esc>[4 q"
]])
vim.cmd[[colorscheme tokyonight-night]]
vim.cmd([[
    augroup RestoreCursorShapeOnExit
        autocmd!
        autocmd VimLeave * set guicursor=a:hor1
    augroup END
]])
vim.api.nvim_set_keymap('n', 'x', '"_x', {noremap = true})
vim.api.nvim_set_keymap('n', 's', '"_s', {noremap = true})
vim.api.nvim_set_keymap('i', 'jj', '<ESC>', {noremap = true, silent = true})
-- vim.o.guicursor = ''
vim.g.NERDTreeShowHidden = 1
vim.g.tokyonight_night_comment = "#00bfff"

require("options")
require("plugins")

require('im_select').setup {
    default_im_select = "com.apple.keylayout.ABC"
}

vim.api.nvim_create_autocmd("VimEnter", {
  pattern = "*",
  callback = function()
    vim.cmd("NERDTree")
    vim.cmd("wincmd p")
  end,
})

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

