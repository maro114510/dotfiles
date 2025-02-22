-- https://github.com/nvim-treesitter/nvim-treesitter.git

return {
	'nvim-treesitter/nvim-treesitter',

	config = function()
		local ts_update = require("nvim-treesitter.install").update({ with_sync = true })
		ts_update()
		require('nvim-treesitter.configs').setup({
			auto_tag = {
				enable = true,
			},
			auto_install = false,
			highlight = {
				enable = true,
			},
			indent = {
				enable = true,
			},
			ensure_installed = {
				'go',
				'lua',
				'rust',
				'toml',
				'typescript',
				'yaml',
			},
		})
	end,

	ft = {
		'go',
		'lua',
		'rust',
		'toml',
		'typescript',
		'yaml',
	},
}
