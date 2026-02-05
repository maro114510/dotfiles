-- https://github.com/hrsh7th/cmp-nvim-lsp.git

return {
  "hrsh7th/nvim-cmp",

  event = "InsertEnter",

  dependencies = {
    "hrsh7th/cmp-nvim-lsp",
    "hrsh7th/cmp-buffer",
    "hrsh7th/cmp-path",
    "hrsh7th/cmp-cmdline",
    "hrsh7th/cmp-vsnip",     -- vsnip 使ってるので
    "onsails/lspkind.nvim",  -- アイコン
    "hrsh7th/vim-vsnip",
    "zbirenbaum/copilot-cmp",
  },

  config = function()
    local cmp = require("cmp")
    local lspkind = require("lspkind")

    -- 共通補完設定
    cmp.setup({
      snippet = {
        expand = function(args)
          vim.fn["vsnip#anonymous"](args.body)
        end,
      },
      window = {
        -- completion = cmp.config.window.bordered(),
        -- documentation = cmp.config.window.bordered(),
      },
      mapping = cmp.mapping.preset.insert({
        ["<C-b>"]    = cmp.mapping.scroll_docs(-4),
        ["<C-f>"]    = cmp.mapping.scroll_docs(4),
        ["<C-Space>"] = cmp.mapping.complete(),
        ["<C-e>"]    = cmp.mapping.abort(),
        ["<CR>"]     = cmp.mapping.confirm({ select = true }),
        ["<C-p>"]    = cmp.mapping.select_prev_item(),
        ["<C-n>"]    = cmp.mapping.select_next_item(),
        ["<C-y>"]    = cmp.mapping.confirm({ select = true }),
      }),
      sources = cmp.config.sources({
        { name = "nvim_lsp" },
        { name = "vsnip" },
        { name = "copilot" },
      }, {
        { name = "buffer" },
        { name = "path" },
      }),
      formatting = {
        format = lspkind.cmp_format({
          mode = "symbol",
          maxwidth = 50,
          ellipsis_char = "...",
        }),
      },
      experimental = {
        ghost_text = false,
      },
    })

    -- gitcommit 用
    cmp.setup.filetype("gitcommit", {
      sources = cmp.config.sources({
        { name = "cmp_git" },
      }, {
        { name = "buffer" },
      }),
    })

    -- `/` と `?` 用（バッファ検索）
    cmp.setup.cmdline({ "/", "?" }, {
      mapping = cmp.mapping.preset.cmdline(),
      sources = {
        { name = "buffer" },
      },
    })

    -- `:` 用（cmdline + path）
    cmp.setup.cmdline(":", {
      mapping = cmp.mapping.preset.cmdline(),
      sources = cmp.config.sources({
        { name = "path" },
      }, {
        { name = "cmdline" },
      }),
    })
  end,
}
