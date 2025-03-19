-- https://github.com/kevinhwang91/nvim-ufo.git
-- The goal of nvim-ufo is to make Neovim's fold look modern and keep high performance.

return {
  'kevinhwang91/nvim-ufo',

  dependencies = {
    'kevinhwang91/promise-async'
  },

  event = "BufRead",

  config = function()
    -- vim.o.foldcolumn = '1' -- 折りたたみ用の列を表示
    vim.o.foldlevel = 99 -- 初期状態ですべての折りたたみを開く
    vim.o.foldlevelstart = 99
    vim.o.foldenable = true
    vim.o.fillchars = [[eob: ,fold: ,foldopen:,foldsep: ,foldclose:]]

    vim.api.nvim_create_autocmd("FileType", {
      pattern = { "neo-tree" },

      callback = function()
        require("ufo").detach()

        vim.opt_local.foldenable = false
      end,
    })

    -- UFOの設定
    require("ufo").setup({
      provider_selector = function(bufnr, filetype, buftype)
        return { "treesitter", "indent" }
      end,
    })
  end,

  keys = {
    {
      mode = { 'n' },
      'zp',
      '<cmd>lua require("ufo").peekFoldedLinesUnderCursor()<cr>',
      desc = 'Peek folded lines under cursor',
    },
  },
}
