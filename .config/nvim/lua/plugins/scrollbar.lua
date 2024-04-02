-- https://github.com/petertriho/nvim-scrollbar.git

return {
	'petertriho/nvim-scrollbar',
	config = function()
		require("scrollbar").setup()
		require('scrollbar.handlers.search').setup()
	end,

	event = "VimEnter"
}
