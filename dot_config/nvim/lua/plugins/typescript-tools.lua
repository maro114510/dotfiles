-- https://github.com/pmizio/typescript-tools.nvim

return {
  "pmizio/typescript-tools.nvim",

  dependencies = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },

  opts = {},

  ft = {
    "javascript",
    "javascriptreact",
    "javascript.jsx",
    "typescript",
    "typescriptreact",
    "typescript.tsx",
  },
}
