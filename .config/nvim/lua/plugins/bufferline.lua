return {
	'akinsho/bufferline.nvim',
	dependencies = 'nvim-tree/nvim-web-devicons',
	opts = function()
		require("bufferline").setup({
			options = {
				mode = "tabs",
				separator_style = 'slant',
				offsets = {
					{ filetype = "neo-tree", text = "", text_align = "center", padding = 1 },
					{ filetype = "NvimTree", text = "", padding =1 },
				},
				max_name_length = 14,
				buffer_close_icon = "",
				modified_icon = "",
				close_icon = "",
				left_trunc_marker = "",
				right_trunc_marker = "",
				max_name_length = 18,
				max_prefix_length = 15, -- prefix used when a buffer is deduplicated
				tab_size = 18,
				enforce_regular_tabs = false,
				view = "multiwindow",
				show_buffer_close_icons = true,
				show_close_icon = true,
				separator_style = "thin",
				always_show_bufferline = true,
				diagnostics = false, -- "or nvim_lsp"
				indicator = { icon = " ", style = "icon" },
				numbers = "ordinal",
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
	end,

	event = "VimEnter",
}
