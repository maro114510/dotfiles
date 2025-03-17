-- https://github.com/folke/trouble.nvim.git
-- A pretty list for showing diagnostics, references, telescope results, quickfix and location lists to help you solve all the trouble your code is causing.

return {
  "folke/trouble.nvim",

  opts = {}, -- for default options, refer to the configuration section for custom setup.

  cmd = "Trouble",

  keys = {
    {
      "<space>xx",
      "<cmd>Trouble diagnostics toggle<cr>",
      desc = "Diagnostics (Trouble)",
    },
  },
}
