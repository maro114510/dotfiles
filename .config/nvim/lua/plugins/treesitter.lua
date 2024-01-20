-- https://github.com/nvim-treesitter/nvim-treesitter.git

return {
	{
		'nvim-treesitter/nvim-treesitter',
		opts = function()
			local ts_update = require("nvim-treesitter.install").update({ with_sync = true })
			ts_update()
			require('nvim-treesitter.configs').setup({
				auto_tag = {
					enable = true,
				},
				auto_install = true,
				highlight = {
					enable = true,
				},
				indent = {
					enable = true,
				},
				ensure_installed = {
					'bash',
					'c',
					'cpp',
					'css',
					'go',
					'html',
					'javascript',
					'json',
					'lua',
					'python',
					'rust',
					'toml',
					'typescript',
					'yaml',
				},
			})
		end
	},
}
