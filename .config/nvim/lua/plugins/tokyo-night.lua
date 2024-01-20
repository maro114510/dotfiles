-- https://github.com/folke/tokyonight.nvim.git

return {
	-- color scheme
	'folke/tokyonight.nvim',
	config = function()
		require('tokyonight').setup {
			transparent = true,
			styles = {
				sidebars = 'transparent',
				floats = 'transparent',
			},
		}
	end,
}
