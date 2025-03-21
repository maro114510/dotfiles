local status, noice = pcall(require, "noice")

if not status then
	return
end

noice.setup({
	lsp = {
		-- override markdown rendering so that **cmp** and other plugins use **treesitter**
		override = {
			--["vim.lsp.util.convert_input_to_markdown_lines"] = true,
			--["vim.lsp.util.stylize_markdown"] = true,
			-- ["cmp.entry.get_documentation"] = true,
		},
	},
	-- you can enable a preset for easier configuration
	presets = {
		bottom_search = false, -- use a classic bottom cmdline for search
		command_palette = false, -- position the cmdline and popupmenu together
		long_message_to_split = false, -- long messages will be sent to a split
		inc_rename = false, -- enables an input dialog for inc-rename.nvim
		lsp_doc_border = false, -- add a border to hover docs and signature help
	},
	messages = {
		-- you can disable any message you want
		error = false,
		warning = false,
		information = false,
		-- hint = false,
		enabled = false,
		-- view_error = "notify",
		-- view_warning = "notify",
		-- view_search = "notify",
	},
})
