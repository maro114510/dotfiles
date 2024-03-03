-- https://github.com/airblade/vim-gitgutter.git

return {
	"airblade/vim-gitgutter",

	event = "VimEnter",
	config = function()
		vim.cmd("GitGutterEnable")
	end,
}
