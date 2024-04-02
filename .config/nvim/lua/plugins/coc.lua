-- https://github.com/neoclide/coc.nvim.git

return {
	'neoclide/coc.nvim',
	branch = 'release',

	event = 'VimEnter',

	keys = {
		{ "<space>dict", "<CMD>CocCommand cSpell.addWordToUserDictionary<CR>", desc = "Add dictionary to cSpell"},
	},
}
