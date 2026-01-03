-- https://github.com/anuvyklack/windows.nvim

return {
  "anuvyklack/windows.nvim",

  dependencies = {
    "anuvyklack/middleclass",
  },

  config = function()
    require("windows").setup({
      ignore = {
        filetype = { "neo-tree", "Neotree", "neo_tree" },
        buftype = { "quickfix" },
      },
    })
  end,

  event = { "BufReadPost", "BufNewFile" },
}
