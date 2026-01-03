-- https://github.com/windwp/nvim-autopairs.git
-- A super powerful autopair plugin for Neovim that supports multiple characters.

return {
  'windwp/nvim-autopairs',

  config = function()
    require'nvim-autopairs'.setup {}
  end,

  event = {"InsertEnter"},
}
