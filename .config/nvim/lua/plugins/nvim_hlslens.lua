-- https://github.com/kevinhwang91/nvim-hlslens.git

return {
	"kevinhwang91/nvim-hlslens",
	config = function()
		require("scrollbar.handlers.search").setup({
			-- hlslens config overrides
		})
	end,
}
