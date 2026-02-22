-- https://github.com/EdenEast/nightfox.nvim.git

return {
  "EdenEast/nightfox.nvim",

  config = function()
    require("nightfox").setup({
      options = {
        transparent = true,
      },
    })

    require("nightfox").load("duskfox")
  end,

  event = "UIEnter",
}
