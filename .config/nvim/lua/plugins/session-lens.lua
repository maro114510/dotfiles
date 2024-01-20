-- https://github.com/rmagatti/session-lens.git

return {
	'rmagatti/session-lens',
	depends = {
		'nvim-lua/plenary.nvim',
		'rmagatti/session-lens',
		'nvim-telescope/telescope.nvim'
	},
	config = function()
		require('session-lens').setup({--[[your custom config--]]})
	end
}
