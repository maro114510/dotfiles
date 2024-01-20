-- https://github.com/nvim-telescope/telescope.nvim.git

return {
	'nvim-telescope/telescope.nvim',
	tag = '0.1.5',
	dependencies = { 'nvim-lua/plenary.nvim' },
	config = function()
		require('telescope').setup {
			live_grep = {
				only_sort_text = true,
				theme = "dropdown",
			},
			extensions = {
				fzf = {
					fuzzy = true, -- false will only do exact matching
					override_generic_sorter = false,
					override_file_sorter = true,
					case_mode = "smart_case", -- or "ignore_case" or "respect_case"
					-- the default case_mode is "smart_case"
				},
			},
			defaults = {
				vimgrep_arguments = {
					"rg",
					"--color=never",
					"--no-heading",
					"--with-filename",
					"--line-number",
					"--column",
					"--smart-case",
					"--hidden",
				},
				prompt_prefix = " 🔭 ",
				selection_caret = "→ ",
				entry_prefix = "  ",
				pickers = {
					find_files = { hidden = true, find_command = { "fd", "--type", "f", "--hidden", "--follow", "-E", ".git/*" }},
					file_browser = { hidden = true },
					live_grep = { hidden = true },
					oldfiles = { hidden = true },
					git_files = { hidden = true },
					buffers = { hidden = true },
				},
				layout_strategy = "horizontal",
				selection_strategy = "reset",
				sorting_strategy = "ascending",
				file_browser = {
					hidden = true,
					ignore_patterns = { "node_modules", ".git" },
				},
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
					i = {
						["<q>"] = require("telescope.actions").close,
						["<esc>"] = require("telescope.actions").close,
					},
					n = {
						["q"] = require("telescope.actions").close,
						["<esc>"] = require("telescope.actions").close,
					},
				},
				color_devicons = true,
				grep_previewer = require("telescope.previewers").vim_buffer_vimgrep.new,
			},
		}
	end,
}
