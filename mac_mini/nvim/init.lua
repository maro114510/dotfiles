# morimori
vim.cmd[[colorscheme tokyonight-night]]
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

