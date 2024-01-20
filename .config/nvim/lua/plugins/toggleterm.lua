-- https://github.com/akinsho/toggleterm.nvim.git

return {
	-- terminal usage
	{
		"akinsho/toggleterm.nvim",
		version = '*',
		config = function() require("toggleterm").setup() end
	},
}
