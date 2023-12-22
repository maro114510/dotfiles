return {
	'nvim-tree/nvim-web-devicons',
	{
		'nvim-lualine/lualine.nvim',
		dependencies = {
			'nvim-tree/nvim-web-devicons',
			opt = true
		},
		opts = function()
			require("lualine").setup({})
		end
	},
}

