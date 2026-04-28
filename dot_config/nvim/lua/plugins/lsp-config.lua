-- https://github.com/neovim/nvim-lspconfig.git
-- Collection of common configurations for the Nvim LSP client

return {
  "neovim/nvim-lspconfig",

  event = { "BufReadPre", "BufNewFile" },

  dependencies = {
    "mason-org/mason.nvim",
    "mason-org/mason-lspconfig.nvim",
    "hrsh7th/cmp-nvim-lsp",
  },

  config = function()
    local on_attach = function(client, bufnr)
      local set = vim.keymap.set
      set("n", "K",         "<cmd>lua vim.lsp.buf.hover()<CR>")
      set("n", "<C-m>",     "<cmd>lua vim.lsp.buf.signature_help()<CR>")
      set("n", "gy",        "<cmd>lua vim.lsp.buf.type_definition()<CR>")
      set("n", "ma",        "<cmd>lua vim.lsp.buf.code_action()<CR>")
      set("n", "gr",        "<cmd>lua vim.lsp.buf.references()<CR>")
      set("n", "<space>e",  "<cmd>lua vim.diagnostic.open_float()<CR>")
      set("n", "[d",        "<cmd>lua vim.diagnostic.goto_prev()<CR>")
      set("n", "]d",        "<cmd>lua vim.diagnostic.goto_next()<CR>")
    end

    -- グローバル設定: 全サーバーに on_attach / capabilities を適用
    vim.lsp.config("*", {
      on_attach    = on_attach,
      capabilities = require("cmp_nvim_lsp").default_capabilities(),
    })

    -- カスタム設定: automatic_enable が vim.lsp.enable() を呼ぶ前に登録する
    vim.lsp.config("typos_lsp", {
      init_options = {
        config = vim.fn.expand("~/.config/nvim/spell/.typos.toml"),
      },
    })

    vim.lsp.config("pylsp", {
      settings = {
        pylsp = {
          plugins = {
            pycodestyle = { ignore = { "E501" } },
          },
        },
      },
    })

    vim.lsp.config("ruff", {
      init_options = {
        settings = {
          lint   = { enable = true, ignore = { "E501" } },
          format = { docstring_code_format = true },
        },
      },
    })

    -- mason-lspconfig: Mason 管理サーバーを自動有効化
    -- glint は cmd/config 引数の既知の非互換のためスキップ
    require("mason-lspconfig").setup({
      ensure_installed = {
        "lua_ls",
        "gopls",
        "terraformls",
        "jsonls",
        "denols",
        "rust_analyzer",
        "bashls",
        "ruff",
        "stylua",
        "html",
        "cssls",
        "pyright",
        "protols",
        "kotlin_language_server",
      },
      automatic_enable = {
        exclude = { "glint" },
      },
    })

    -- Mason 管理外サーバーは手動で有効化
    vim.lsp.enable("sourcekit")
    vim.lsp.enable("typos_lsp")
    vim.lsp.enable("pylsp")
  end,
}
