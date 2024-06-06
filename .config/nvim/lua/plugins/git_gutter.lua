-- https://github.com/airblade/vim-gitgutter.git

return {
	--[[ "airblade/vim-gitgutter",

	event = "VimEnter",
	config = function()
		vim.cmd("GitGutterEnable")
		-- vivid green
		-- vim.cmd("highlight SignColumn guibg=NONE guifg=#00FF00")
		vim.cmd("highlight GitGutterAdd guifg=#009900 ctermfg=2")
		vim.cmd("highlight GitGutterChange guifg=#bbbb00 ctermfg=3")
		vim.cmd("highlight GitGutterDelete guifg=#ff2222 ctermfg=1")
	end, ]]
}
