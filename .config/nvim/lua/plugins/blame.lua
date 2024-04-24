-- https://github.com/FabijanZulj/blame.nvim.git

return {
	"FabijanZulj/blame.nvim",
	config = function()
		require("blame").setup()
	end,

	cmd = "BlameToggle",
}
