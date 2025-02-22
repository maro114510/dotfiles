-- https://github.com/folke/noice.nvim.git

return {
	-- lazy.nvim
	"folke/noice.nvim",
	dependencies = {
		-- if you lazy-load any plugin below, make sure to add proper `module="..."` entries
		"MunifTanjim/nui.nvim",
		-- OPTIONAL:
		--   `nvim-notify` is only needed, if you want to use the notification view.
		--   If not available, we use `mini` as the fallback
		-- "rcarriga/nvim-notify",
	},

	-- event = "BufRead",
	-- event = "VeryLazy",
	-- yakiii

	config = function()
		require("noice").setup({
			-- debug = true,
			lsp = {
				-- override markdown rendering so that **cmp** and other plugins use **treesitter**
				override = {
					["vim.lsp.util.convert_input_to_markdown_lines"] = true,
					-- ["vim.lsp.util.stylize_markdown"] = true,
					["cmp.entry.get_documentation"] = true,
				},
			},
			-- you can enable a preset for easier configuration
			presets = {
				bottom_search = false, -- use a classic bottom cmdline for search
				command_palette = false, -- position the cmdline and popupmenu together
				long_message_to_split = false, -- long messages will be sent to a split
				inc_rename = true, -- enables an input dialog for inc-rename.nvim
				lsp_doc_border = true, -- add a border to hover docs and signature help
			},
			messages = {
				-- you can disable any message you want
				error = true,
				warning = true,
				information = true,
				-- hint = false,
				enabled = true,
				-- view_error = "notify",
				-- view_warning = "notify",
				-- view_search = "notify",
			},
		})
	end,
}
