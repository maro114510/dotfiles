return {
	'nvim-tree/nvim-web-devicons',
	{
		'nvim-lualine/lualine.nvim',
		dependencies = {
			'nvim-tree/nvim-web-devicons',
			opt = true
		},
		opts = function()
			require("lualine").setup({
				sections = {
					lualine_x = {
					{
						require("lazy.status").updates,
						cond = require("lazy.status").has_updates,
						color = { fg = "#ff9e64" },
					},
					},
				},
			})
		end
	},
}

