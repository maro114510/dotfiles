-- https://github.com/RRethy/vim-illuminate.git

return {
	"RRethy/vim-illuminate",
	config = function()
		vim.g.Illuminate_delay = 1000
		vim.g.Illuminate_ftblacklist = { "NvimTree", "packer" }
	end,

	event = "UIEnter"
}
