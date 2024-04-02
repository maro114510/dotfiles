-- https://github.com/windwp/nvim-autopairs.git

return {
	'windwp/nvim-autopairs',
	config = function() require'nvim-autopairs'.setup {} end,

	event = 'VimEnter',
}

