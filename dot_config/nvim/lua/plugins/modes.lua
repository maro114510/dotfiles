-- https://github.com/mvllow/modes.nvim

return {
  "mvllow/modes.nvim",

  version = "*",

  config = function()
    require("modes").setup({
      line_opacity = 0.50,
    })
  end,

  event = { "BufReadPost", "BufNewFile" },
}
