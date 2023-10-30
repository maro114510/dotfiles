vim.cmd[[colorscheme tokyonight-night]]

require("options")
require("plugins")

require('im_select').setup {
    default_im_select = "com.apple.keylayout.ABC"
}

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


