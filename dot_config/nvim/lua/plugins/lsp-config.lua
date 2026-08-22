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
      -- Conform owns formatting for these language clients. Keeping the LSP
      -- capability enabled would make :lua vim.lsp.buf.format() ambiguous.
      local conform_owned_formatting = {
        gopls = true,
        ruff = true,
        ["typescript-tools"] = true,
      }
      if conform_owned_formatting[client.name] then
        client.server_capabilities.documentFormattingProvider = false
        client.server_capabilities.documentRangeFormattingProvider = false
      end

      local set = vim.keymap.set
      set("n", "K", "<cmd>lua vim.lsp.buf.hover()<CR>")
      set("n", "<C-m>", "<cmd>lua vim.lsp.buf.signature_help()<CR>")
      set("n", "gy", "<cmd>lua vim.lsp.buf.type_definition()<CR>")
      set("n", "ma", "<cmd>lua vim.lsp.buf.code_action()<CR>")
      set("n", "<leader>e", "<cmd>lua vim.diagnostic.open_float()<CR>")
    end

    -- グローバル設定: 全サーバーに on_attach / capabilities を適用
    vim.lsp.config("*", {
      on_attach = on_attach,
      capabilities = require("cmp_nvim_lsp").default_capabilities(),
    })

    -- カスタム設定: automatic_enable が vim.lsp.enable() を呼ぶ前に登録する
    vim.lsp.config("typos_lsp", {
      init_options = {
        config = vim.fn.expand("~/.config/nvim/spell/.typos.toml"),
      },
    })

    vim.lsp.config("ruff", {
      init_options = {
        settings = {
          lint = { enable = true, ignore = { "E501" } },
          format = { docstring_code_format = true },
        },
      },
    })

    vim.lsp.config("lua_ls", {
      settings = {
        Lua = { diagnostics = { globals = { "vim" } } },
      },
    })

    -- mason-lspconfig: only the declared servers are installed and enabled.
    -- This allowlist prevents unrelated servers already in Mason from attaching.
    local language_servers = {
      "lua_ls",
      "gopls",
      "terraformls",
      "jsonls",
      "rust_analyzer",
      "bashls",
      "ruff",
      "html",
      "cssls",
      "buf_ls",
      "kotlin_language_server",
    }
    require("mason-lspconfig").setup({
      ensure_installed = language_servers,
      automatic_enable = language_servers,
    })

    -- Mason 管理外サーバーは手動で有効化
    vim.lsp.enable("sourcekit")
    vim.lsp.enable("typos_lsp")
  end,
}
