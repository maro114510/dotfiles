-- https://github.com/shellRaining/hlchunk.nvim.git

return {
  "shellRaining/hlchunk.nvim",

  config = function()
    require("hlchunk").setup({
      chunk = {
        enable = true,
      },
      indent = {
        enable = true,
      },
    })
  end,

  event = { "BufReadPost", "BufNewFile" },
}
