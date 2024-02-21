-- https://github.com/folke/trouble.nvim.git

return {
	"folke/trouble.nvim",
	requires = {
		"nvim-tree/nvim-web-devicons",
	},
	config = function()
		vim.api.nvim_set_keymap(
			"n",
			"<space>xx",
			"<cmd>TroubleToggle workspace_diagnostics<cr>",
			{ noremap = true, silent = true }
		)
		vim.api.nvim_set_keymap(
			"n",
			"<space>xw",
			"<cmd>TroubleToggle quickfix<cr>",
			{ noremap = true, silent = true }
		)
	end,

	keys = {
		"<space>xx",
	},
}
