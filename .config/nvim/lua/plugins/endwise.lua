-- https://github.com/RRethy/nvim-treesitter-endwise.git

return {
	{
		'RRethy/nvim-treesitter-endwise',
		config = function()
			require('nvim-treesitter.configs').setup {
				endwise = {
					enable = true,
				},
			}
		end,
	}
}
