-- https://github.com/shellRaining/hlchunk.nvim.git

return {
	"shellRaining/hlchunk.nvim",
	config = function()
		require("hlchunk").setup({})
	end,

	event = { "UIEnter" },
}
