-- https://github.com/nvim-neo-tree/neo-tree.nvim.git

return {
	"nvim-neo-tree/neo-tree.nvim",
	branch = "v3.x",
	dependencies = {
		"nvim-tree/nvim-web-devicons",
		"nvim-lua/plenary.nvim",
		"MunifTanjim/nui.nvim"
	},
	opts = {
		enable_git_status = true,
		filesystem = {
			filtered_items = {
				visible = true,
				show_hidden_count = true,
				hide_dotfiles = false,
				hide_gitignored = true,
				hide_by_name = {
					'.git',
					'.DS_Store',
				},
				never_show = { -- remains hidden even if visible is toggled to true, this overrides always_show
					".DS_Store",
					"thumbs.db"
				},
			},
		},
		event_handlers = {
			{
				event = "file_closed",
				handler = function()
					require("neo-tree.command").execute({ action = "close" })
				end,
			},
			{
				event = "vim_buffer_enter",
				handler = function(_)
					if vim.bo.filetype == "neo-tree" then vim.wo.signcolumn = "auto" end
				end,
			}
		},
		window ={
			width = 30,
		},
		default_component_configs = {
			indent = {
			indent_size = 2,
				padding = 0,
				with_markers = true,
				indent_marker = "│",
				last_indent_marker = "└",
				highlight = "NeoTreeIndentMarker",
				with_expanders = true,
				expander_collapsed = "",
				expander_expanded = "",
				expander_highlight = "NeoTreeExpander",
			},
			icon = {
				folder_closed = "",
				folder_open = "",
				folder_empty = "",
				default = "",
			},
			name = { trailing_slash = false, use_git_status_colors = true },
			git_status = {
				symbols = {
					added = "",
					deleted = "",
					modified = "",
					renamed = "➜",
					untracked = "★",
					ignored = "◌",
					unstaged = "✗",
					staged = "✓",
					conflict = "",
				},
			},
		}
	},

	event = "VimEnter",
}
