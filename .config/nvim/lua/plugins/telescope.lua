-- https://github.com/nvim-telescope/telescope.nvim.git

return {
	'nvim-telescope/telescope.nvim',
	tag = '0.1.5',
	dependencies = { 'nvim-lua/plenary.nvim' },
	opt = function()
		require('telescope').setup {
			defaults = {
				vimgrep_arguments = {
					"rg",
					"-L",
					"--color=never",
					"--no-heading",
					"--with-filename",
					"--line-number",
					"--column",
					"--smart-case",
				},
				prompt_prefix = "   ",
				selection_caret = "  ",
				entry_prefix = "  ",
				layout_strategy = "horizontal",
				selection_strategy = "reset",
				sorting_strategy = "ascending",
				layout_config = {
					horizontal = {
						prompt_position = "top",
						preview_width = 0.55,
						results_width = 0.8,
					},
					vertical = {
						mirror = false,
					},
					width = 0.87,
					preview_cutoff = 120,
				},
				mappings = {
					n = {
						["q"] = require("telescope.actions").close,
						["<C-j>"] = require("telescope.actions").move_selection_next,
						["<C-k>"] = require("telescope.actions").move_selection_previous,
						["<C-c>"] = require("telescope.actions").close,
						["<C-q>"] = require("telescope.actions").smart_send_to_qflist + require("telescope.actions").open_qflist,
						["<CR>"] = require("telescope.actions").select_default + require("telescope.actions").center,
						["<esc>"] = require("telescope.actions").close,
					},
					i = {
						["<C-j"] = require("telescope.actions").move_selection_next,
						["<C-k>"] = require("telescope.actions").move_selection_previous,
						["<C-c>"] = require("telescope.actions").close,
						["<C-q>"] = require("telescope.actions").smart_send_to_qflist + require("telescope.actions").open_qflist,
						["<CR>"] = require("telescope.actions").select_default + require("telescope.actions").center,
						["<esc>"] = require("telescope.actions").close,
					},
				},
				color_devicons = true,
				grep_previewer = require("telescope.previewers").vim_buffer_vimgrep.new,
			},
		}
	end,
}
