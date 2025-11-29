-- https://github.com/stevearc/oil.nvim.git
-- A vim-vinegar like file explorer that lets you edit your filesystem like a normal Neovim buffer.

return {
  'stevearc/oil.nvim',

  opts = {},

  dependencies = { "nvim-tree/nvim-web-devicons" },

  config = function()
    require('oil').setup({
      view_options = {
        show_hidden = true,
      }
    })
  end,

  cmd = { "Oil" },

  keys = {
    {
      "-",
      "<cmd>Oil<CR>",
      mode = "n",
    },
  },
}
