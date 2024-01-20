-- https://github.com/petertriho/nvim-scrollbar.git

return {
	'petertriho/nvim-scrollbar',
	opt = function()
		require("scrollbar").setup()
		require('scrollbar.handlers.search').setup()
	end,
}
