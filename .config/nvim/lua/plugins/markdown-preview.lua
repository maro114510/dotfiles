-- https://github.com/iamcco/markdown-preview.nvim.git

return {
	-- markdown preview
	"iamcco/markdown-preview.nvim",
	build = function() vim.fn["mkdp#util#install"]() end,

	event = "VeryLazy",
}

