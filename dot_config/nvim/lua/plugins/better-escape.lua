-- https://github.com/max397574/better-escape.nvim

return   {
  "max397574/better-escape.nvim",

  event = { "BufReadPre", "BufWritePre", "BufNewFile" },

  opts = {
    timeout = 100,
    default_mappings = false,
    mappings = {
      i = { j = { k = "<ESC>" } },
      t = {
        j = { k = "<C-\\><C-n>" },
      },
    },
  },
}
