-- https://github.com/stevearc/aerial.nvim.git

return {
	'stevearc/aerial.nvim',

	opts = {},

	-- Optional dependencies
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
		"nvim-tree/nvim-web-devicons"
	},

	config = function()
		require("aerial").setup({
		-- optionally use on_attach to set keymaps when aerial has attached to a buffer
		on_attach = function(bufnr)
			-- Jump forwards/backwards with '{' and '}'
			vim.keymap.set("n", "{", "<cmd>AerialOpen<CR>", { buffer = bufnr })
			vim.keymap.set("n", "}", "<cmd>AerialClose<CR>", { buffer = bufnr })
		end,
		})
	end,

	event = "VeryLazy",
}

