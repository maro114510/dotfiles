-- https://github.com/FabijanZulj/blame.nvim.git
-- git blame plugin

return {
  "FabijanZulj/blame.nvim",

  config = function()
    require("blame").setup()
  end,

  cmd = "BlameToggle",
}
