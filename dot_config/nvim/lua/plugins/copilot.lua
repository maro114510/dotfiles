-- https://github.com/github/copilot.vim.git

return {
  {
    "github/copilot.vim",

    event = "BufRead",
  },

  -- {
  --   "zbirenbaum/copilot.lua",
  --
  --   lazy = false,
  --
  --   dependencies = {
  --     "copilotlsp-nvim/copilot-lsp",
  --   },
  --
  --   config = function()
  --     require("copilot").setup({
  --       panel = {
  --         enabled = false,
  --       },
  --       suggestion = {
  --         enabled = true,
  --         auto_trigger = true,
  --       },
  --       filetypes = { yaml = true, markdown = true, gitcommit = true, ["*"] = true },
  --       keymaps = {
  --         accept = "<C-l>",
  --       },
  --     })
  --   end,
  -- },

  -- {
  -- 	"zbirenbaum/copilot-cmp",
  --
  -- 	dependencies = { "zbirenbaum/copilot.lua", "hrsh7th/nvim-cmp", },
  --
  -- 	config = function ()
  -- 		require("copilot_cmp").setup()
  -- 	end,
  --
  --   event = "BufRead",
  -- },
}
