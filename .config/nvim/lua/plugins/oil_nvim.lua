-- https://github.com/stevearc/oil.nvim.git

return {
	'stevearc/oil.nvim',
	opts = {},
	-- Optional dependencies
	dependencies = { "nvim-tree/nvim-web-devicons" },

	config = function()
		require('oil').setup()
	end,

	event = "UIEnter",
}
