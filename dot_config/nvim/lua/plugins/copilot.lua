-- https://github.com/github/copilot.vim.git

return {
  -- {
  --   "github/copilot.vim",
  --
  --   init = function()
  --     vim.g.copilot_node_command = vim.fn.expand("~/.local/share/mise/installs/node/latest/bin/node")
  --   end,
  --
  --   event = "BufRead",
  -- },

  {
    "zbirenbaum/copilot.lua",

    event = "InsertEnter",
    cmd = "Copilot",

    dependencies = {
      "copilotlsp-nvim/copilot-lsp",
    },

    config = function()
      require("copilot").setup({
        panel = {
          enabled = false,
        },
        suggestion = {
          enabled = true,
          auto_trigger = true,
          keymap = {
            accept = "<Tab>",
          },
        },
        filetypes = { yaml = true, markdown = true, gitcommit = true, ["*"] = true },
      })
    end,
  },

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
