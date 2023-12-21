return {
	{
		'nvim-treesitter/nvim-treesitter',
		build = ':TsUpdate',
		opts = function()
			require('nvim-treesitter.configs').setup({
				auto_install = true,
				highlight = {
					enable = true,
				},
			})
		end
	},

}