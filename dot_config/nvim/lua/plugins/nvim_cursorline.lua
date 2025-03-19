-- https://github.com/ya2s/nvim-cursorline
-- Highlight words and lines on the cursor for Neovim

return {
  'yamatsum/nvim-cursorline',

  config = function()
    require('nvim-cursorline').setup {
      cursorline = {
        enable = true,
        timeout = 1000,
        number = false,
      },

      cursorword = {
        enable = true,
        min_length = 3,
        hl = { underline = true },
      }
    }
  end,

  event = 'UIEnter',
}
