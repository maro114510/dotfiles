-- https://github.com/smjonas/inc-rename.nvim
-- Live preview of LSP rename in the command line (integrates with noice.nvim)

return {
  "smjonas/inc-rename.nvim",

  cmd = "IncRename",

  keys = {
    {
      "<leader>rn",
      function()
        return ":IncRename " .. vim.fn.expand("<cword>")
      end,
      expr = true,
      desc = "LSP: Incremental rename",
    },
  },

  opts = {},
}
