-- https://github.com/lewis6991/gitsigns.nvim.git
-- Deep buffer integration for Git

return {
  'lewis6991/gitsigns.nvim',

  event = { 'BufReadPre' },

  config = function()
    require('gitsigns').setup()
  end
}
