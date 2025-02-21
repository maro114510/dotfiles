-- https://github.com/rachartier/tiny-inline-diagnostic.nvim.git

return {
	"rachartier/tiny-inline-diagnostic.nvim",

	event = "VeryLazy", -- Or `LspAttach`
	priority = 1000, -- needs to be loaded in first

	config = function()
		vim.diagnostic.config({ virtual_text = false })

		require('tiny-inline-diagnostic').setup({
			preset = 'ghost',
			options = {
				multilines = {
					always_show = true,
				},
				show_all_diags_on_cursorline = true,
			}
		})
	end
}
