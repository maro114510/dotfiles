-- https://github.com/max397574/better-escape.nvim

return {
  "max397574/better-escape.nvim",

  event = { "BufReadPre", "BufWritePre", "BufNewFile" },

  opts = {
    timeout = 100,
    default_mappings = false,
    mappings = {
      i = {
        j = {
          j = "<ESC>", -- jj
          k = "<ESC>", -- jk
        },
      },
      t = {
        j = { k = "<C-\\><C-n>" },
      },
    },
  },
}
