
-- vim.cmd[[colorscheme nord]]

require("bufferline").setup({
	options = {
		mode = "tabs",
		separator_style = 'slant',
	},
	highlights = {
		separator = {
			guifg = '#073642',
			guibg = '#002b36',
		},
		separator_selected = {
			guifg = '#073642',
		},
		background = {
			guifg = '#657b83',
			guibg = '#002b36'
		},
		buffer_selected = {
			guifg = '#fdf6e3',
			gui = "bold",
		},
		fill = {
			guibg = '#073642'
		}
	},
})

require('nvim-cursorline').setup {
  cursorline = {
    enable = true,
    timeout = 1000,
    number = false,
  },
  cursorword = {
    enable = true,
    min_length = 3,
    hl = { underline = true },
  }
}

