-- https://github.com/stevearc/oil.nvim.git
-- A vim-vinegar like file explorer that lets you edit your filesystem like a normal Neovim buffer.

return {
  'stevearc/oil.nvim',

  opts = {},

  dependencies = { "nvim-tree/nvim-web-devicons" },

  config = function()
    require('oil').setup({
      delete_to_trash = true,
      view_options = {
        show_hidden = true,
      },
      skip_confirm_for_simple_edits = true,
      columns = {
        "icon",
        "permissions",
        "size",
        "mtime",
      },
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
