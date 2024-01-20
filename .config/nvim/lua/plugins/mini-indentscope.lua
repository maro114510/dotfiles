-- https://github.com/echasnovski/mini.indentscope.git

return {
	{
		'echasnovski/mini.indentscope',
		config = function()
			require('mini.indentscope').setup({
				symbol = '▏',
			})
		end
	}
}

