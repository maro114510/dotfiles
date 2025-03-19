-- https://github.com/github/copilot.vim.git

return {
  {
    'github/copilot.vim',

    -- "zbirenbaum/copilot.lua",
    -- cmd = "Copilot",
    -- event = "InsertEnter",
    -- opts = function()
    -- 	require("copilot").setup({})
    -- end,

    event = "VimEnter",
  },

  -- {
  -- 	"zbirenbaum/copilot-cmp",
  -- 	dependencies = { "copilot.lua" },
  -- 	config = function ()
  -- 		require("copilot_cmp").setup()
  -- 	end
  -- },
}
