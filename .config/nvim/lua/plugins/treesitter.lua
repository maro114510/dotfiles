return {
	{
		'nvim-treesitter/nvim-treesitter',
		build = ':TsUpdate',
		opts = function()
			require('nvim-treesitter.configs').setup({
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
