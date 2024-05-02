-- https://github.com/akinsho/flutter-tools.nvim.git

return {
    'akinsho/flutter-tools.nvim',

    dependencies = {
        'nvim-lua/plenary.nvim',
        'stevearc/dressing.nvim', -- optional for vim.ui.select
    },

    config = true,
	ft = {
		"dart",
	},
}
