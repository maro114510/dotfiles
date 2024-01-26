-- https://github.com/folke/trouble.nvim.git

return {
	"folke/trouble.nvim",
	requires = {
		"nvim-tree/nvim-web-devicons",
	},
	keys = {
		"<space>xx",
	},
	config = function()
		vim.api.nvim_set_keymap(
			"n",
			"<space>xx",
			"<cmd>TroubleToggle document_diagnostics<cr>",
			{ noremap = true, silent = true }
		)
	end,
}
