-- https://github.com/shellRaining/hlchunk.nvim.git

return {
	"shellRaining/hlchunk.nvim",
	event = { "UIEnter" },
	config = function()
		require("hlchunk").setup({})
	end
}
