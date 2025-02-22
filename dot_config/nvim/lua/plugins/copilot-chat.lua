-- https://github.com/CopilotC-Nvim/CopilotChat.nvim.git

vim.opt.splitright = true

return {
	"CopilotC-Nvim/CopilotChat.nvim",
	dependencies = {
		{ "github/copilot.vim" }, -- or zbirenbaum/copilot.lua
		{ "nvim-lua/plenary.nvim", branch = "master" }, -- for curl, log and async functions
	},
	build = "make tiktoken", -- Only on MacOS or Linux
	opts = {
		window = {
			layout = 'vertical',
			width = 0.3,
			height = 0.5,
		},
	},
	keys = {
		{ "<C-x><C-x>", "<cmd>CopilotChat<CR>", mode = { "n", "v" } },
	},
	cmd = "CopilotChat",
}
