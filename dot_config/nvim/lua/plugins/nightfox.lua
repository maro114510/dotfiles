-- https://github.com/EdenEast/nightfox.nvim.git

return {
  "EdenEast/nightfox.nvim",
  lazy = false,
  priority = 1000,

  config = function()
    require("nightfox").setup({
      options = {
        transparent = true,
      },
      groups = {
        all = {
          Normal = { bg = "NONE" },
          Comment = { fg = "#ffd700", style = "italic" },
          ["@comment"] = { fg = "#ffd700", style = "italic" },
        },
      },
    })

    vim.cmd("colorscheme duskfox")
  end,
}
