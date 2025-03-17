-- https://github.com/hrsh7th/cmp-nvim-lsp.git

return {
  {
    -- LSPを補完候補に追加
    'hrsh7th/cmp-nvim-lsp',
    event = 'BufRead',
  },
  {
    -- バッファの補完候補を追加
    'hrsh7th/cmp-buffer',
    event = 'BufRead',
  },
  {
    -- パスの補完候補を追加
    'hrsh7th/cmp-path',
    event = 'BufRead',
  },
  {
    -- コマンドラインの補完候補を追加
    'hrsh7th/cmp-cmdline',
    event = 'CmdlineEnter',
  },
  {
    -- スニペットエンジン本体
    -- 'hrsh7th/vim-vsnip',
    -- event = 'InsertCharPre',
  },
  {
    -- 補完エンジン本体
    'hrsh7th/nvim-cmp',
    event = 'InsertEnter',
  },
}
