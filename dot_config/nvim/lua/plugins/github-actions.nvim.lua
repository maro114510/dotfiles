-- https://github.com/skanehira/github-actions.nvim

return {
  'skanehira/github-actions.nvim',

  dependencies = {
    'nvim-treesitter/nvim-treesitter',
    'nvim-telescope/telescope.nvim',  -- Optional: for enhanced workflow selection
  },

  opts = {},

  ft = { 'yaml', 'yml' },
}
