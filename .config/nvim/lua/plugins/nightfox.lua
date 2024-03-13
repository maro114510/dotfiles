-- https://github.com/EdenEast/nightfox.nvim.git

return {
	"EdenEast/nightfox.nvim",

	config = function()
		require('nightfox').setup {
			transparent = true,
			styles = {
				sidebars = 'transparent',
				floats = 'transparent',
			},
		}
	end,

	event = "UIEnter",
}
