-- https://github.com/rachartier/tiny-inline-diagnostic.nvim.git

return {
	"rachartier/tiny-inline-diagnostic.nvim",

	event = "LspAttach", -- Or `LspAttach`
	priority = 500, -- needs to be loaded in first

	config = function()
		vim.diagnostic.config({ virtual_text = false }) -- Only if needed in your configuration, if you already have native LSP diagnostics

		require('tiny-inline-diagnostic').setup({
			preset = 'ghost',
			options = {
				overwrite_events = { "DiagnosticChanged" },
			}
		})
	end
}
