-- https://github.com/lewis6991/gitsigns.nvim.git

return {
	'lewis6991/gitsigns.nvim',
	event = { 'BufReadPre' },

	config = function()
		require('gitsigns').setup()
	end
}
