-- https://github.com/elentok/format-on-save.nvim.git

return {
	"elentok/format-on-save.nvim",

	config = function()
		local format_on_save = require("format-on-save")
		local formatters = require("format-on-save.formatters")

		format_on_save.setup({
			exclude_path_patterns = {
				"/node_modules/",
				".local/share/nvim/lazy",
			},
			formatter_by_ft = {
				rust = formatters.lsp,
			},
			fallback_formatter = {
				formatters.remove_trailing_whitespace,
				formatters.remove_trailing_newlines,
			},
		})
	end,

	ft = {
		"rust",
		"sh",
		"lua",
		"json",
		"yaml",
		"toml",
	},
}
