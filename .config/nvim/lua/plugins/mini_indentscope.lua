
return {
	{
		'echasnovski/mini.indentscope',
		config = function()
			require('mini.indentscope').setup({
				symbol = '▏',
			})
		end,

		event = 'UIEnter',
	}
}

