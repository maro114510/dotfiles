-- https://github.com/mrjones2014/legendary.nvim.git

return {
	'mrjones2014/legendary.nvim',
	version = 'v2.1.0',
	-- since legendary.nvim handles all your keymaps/commands,
	-- its recommended to load legendary.nvim before other plugins
	priority = 10000,
	lazy = false,
	-- sqlite is only needed if you want to use frecency sorting
	-- dependencies = { 'kkharji/sqlite.lua' }
	opt = function()
		require('legendary').setup({ lazy_nvim = { auto_register = true } })
	end
}
