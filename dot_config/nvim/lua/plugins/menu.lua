-- https://github.com/nvzone/menu

return {
  { "nvzone/volt", lazy = true },
  {
    "nvzone/menu",
    lazy = true,
    keys = {
      {
        "<RightMouse>",
        function()
          require("menu").open("default")
        end,
        desc = "Open menu",
      },
    },
  },
}
