-- https://github.com/monaqa/dial.nvim.git

return {
	"monaqa/dial.nvim",

	config = function()
		vim.keymap.set(
			"n",
			"<C-a>",
			function() require("dial.map").manipulate("increment", "normal") end
		)
		vim.keymap.set(
			"n",
			"<C-x>",
			function() require("dial.map").manipulate("decrement", "normal") end
		)
	end,
}
