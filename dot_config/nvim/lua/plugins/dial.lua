-- https://github.com/monaqa/dial.nvim.git
-- Increment and decrement number under cursor

return {
  "monaqa/dial.nvim",

  config = function()
    local augend = require("dial.augend")

    require("dial").setup()
    require("dial.config").augends:register_group{
      default = {
        augend.integer.alias.decimal,      -- 整数
        augend.integer.alias.hex,          -- 16進数
        augend.constant.alias.bool,        -- true/false
        augend.constant.new{
          elements = {"and", "or"},      -- and/or
          word = true,
          cyclic = true,
        },

      augend.constant.new{
        elements = {"&&", "||"},       -- &&/||
        word = false,
        cyclic = true,
        },
      },
    }
  end,

  keys = {
    {
      "n",
      "<C-a>",
      [[<cmd>lua require('dial').increment()<CR>]],
      { noremap = true, silent = true },
    },
    {
      "n",
      "<C-x>",
      [[<cmd>lua require('dial').decrement()<CR>]],
      { noremap = true, silent = true },
    },
  }
}
