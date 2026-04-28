-- https://github.com/EdenEast/nightfox.nvim.git

return {
  "EdenEast/nightfox.nvim",

  config = function()
    require("nightfox").setup({
      options = {
        transparent = true,
      },
    })

    vim.cmd("colorscheme duskfox")
  end,

  event = "UIEnter",
}
