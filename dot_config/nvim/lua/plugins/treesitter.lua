-- https://github.com/nvim-treesitter/nvim-treesitter.git

return {
  'nvim-treesitter/nvim-treesitter',

  config = function()
    local ts_update = require("nvim-treesitter.install").update({ with_sync = true, silent = true })

    ts_update()

    require('nvim-treesitter.configs').setup({
      auto_tag = {
        enable = true,
      },

      auto_install = true,

      highlight = {
        enable = true,
      },

      indent = {
        enable = true,
      },

      ensure_installed = {
        'go',
        'lua',
        'rust',
        'toml',
        'typescript',
        'yaml',
      },

      notify = false,
    })
  end,

  ft = {
    'go',
    'lua',
    'rust',
    'toml',
    'typescript',
    'yaml',
  },
}
