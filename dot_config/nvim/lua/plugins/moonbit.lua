-- https://github.com/moonbit-community/moonbit.nvim.git
-- LSP + Tree-sitter support for MoonBit

return {
  "moonbit-community/moonbit.nvim",

  ft = { "moonbit" },

  opts = {
    mooncakes = {
      virtual_text = true,
      use_local = true,
    },
    treesitter = {
      enabled = true,
      auto_install = true,
    },
    lsp = {
      native = true,
      capabilities = require("cmp_nvim_lsp").default_capabilities(),
    },
  },
}
