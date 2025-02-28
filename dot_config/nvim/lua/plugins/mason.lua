-- https://github.com/williamboman/mason.nvim.git
-- https://github.com/williamboman/mason-lspconfig.nvim.git

return {
	{
		"williamboman/mason.nvim",

		-- Config
		config = function()
			require("mason").setup()
		end,
	},
	{
		"williamboman/mason-lspconfig.nvim",
	}
}
