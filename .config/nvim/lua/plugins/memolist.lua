-- https://github.com/glidenote/memolist.vim.git

return {
	'glidenote/memolist.vim',

	event = 'BufReadPre',
	config = function()
		vim.g.memolist_dir = '~/memo'
		vim.g.memolist_memo_suffix = "md"
		vim.g.memolist_prompt_tags = 1
		vim.g.memolist_prompt_categories = 1
		vim.g.memolist_fzf = 1
		vim.g.memolist_ex_cmd = 'NERDTree'
		vim.g.memolist_template_dir_path = '~/memo'
	end,
}
