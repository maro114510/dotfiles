-- https://github.com/junegunn/fzf.vim.git

return {
	-- fzf
	{
		'junegunn/fzf.vim',
		dependencies = {
			'junegunn/fzf',
		},
		build = ':call fzf#install()',

		event = 'VimEnter',
	},
	{
		'ibhagwan/fzf-lua',
		-- optional for icon support
		dependencies = {
			-- 'kyazdani42/nvim-web-devicons',
			'nvim-tree/nvim-web-devicons',
		},
		event = 'VimEnter',
	},
}

