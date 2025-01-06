-- https://github.com/EdenEast/nightfox.nvim.git

return {
	"EdenEast/nightfox.nvim",

	config = function()
		require('nightfox').setup {
			transparent = true,
		}
		require('nightfox').load()
	end,

	event = "UIEnter",
}
