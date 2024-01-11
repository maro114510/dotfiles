return {
	"nvim-neo-tree/neo-tree.nvim",
	branch = "v3.x",
	dependencies = {
		"nvim-tree/nvim-web-devicons",
		"nvim-lua/plenary.nvim",
		"MunifTanjim/nui.nvim"
	},
	opts = {
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
			never_show = {},
			},
		},
		event_handlers = {
			{
				event = "file_closed",
				handler = function()
					require("neo-tree.command").execute({ action = "close" })
				end,
			}
		}
	}
}
