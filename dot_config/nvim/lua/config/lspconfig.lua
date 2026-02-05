local on_attach = function(client, bufnr)
  -- LSPが持つフォーマット機能を無効化する
  -- →例えばtsserverはデフォルトでフォーマット機能を提供しますが、利用したくない場合はコメントアウトを解除してください
  --client.server_capabilities.documentFormattingProvider = false

  -- 下記ではデフォルトのキーバインドを設定しています
  -- ほかのLSPプラグインを使う場合（例：Lspsaga）は必要ないこともあります

  local set = vim.keymap.set
  -- set("n", "gd", "<cmd>lua vim.lsp.buf.definition()<CR>")
  set("n", "K", "<cmd>lua vim.lsp.buf.hover()<CR>")
  set("n", "<C-m>", "<cmd>lua vim.lsp.buf.signature_help()<CR>")
  set("n", "gy", "<cmd>lua vim.lsp.buf.type_definition()<CR>")
  -- LSP Rename は keymap.lua で安全な実装を使用
  set("n", "ma", "<cmd>lua vim.lsp.buf.code_action()<CR>")
  set("n", "gr", "<cmd>lua vim.lsp.buf.references()<CR>")
  set("n", "<space>e", "<cmd>lua vim.diagnostic.open_float()<CR>")
  set("n", "[d", "<cmd>lua vim.diagnostic.goto_prev()<CR>")
  set("n", "]d", "<cmd>lua vim.diagnostic.goto_next()<CR>")
end

-- 補完プラグインであるcmp_nvim_lspをLSPと連携させています
local capabilities = require("cmp_nvim_lsp").default_capabilities()

-- LSP共通オプションを適用しつつvim.lsp.config経由で有効化するユーティリティ
-- vim.lsp.config()関数を使用してnvim-lspconfigのデフォルト設定（filetypes等）とマージする
local function configure(server_name, opts)
  local config = vim.tbl_deep_extend("force", {
    on_attach = on_attach,
    capabilities = capabilities,
  }, opts or {})

  vim.lsp.config(server_name, config)
  vim.lsp.enable(server_name)
end

-- まず mason をセットアップ
require("mason").setup()

-- mason-lspconfigが読み込めるか確認
local mason_lspconfig_status, mason_lspconfig = pcall(require, "mason-lspconfig")
if not mason_lspconfig_status then
  print("mason-lspconfig is not installed or not found")
  return
end

mason_lspconfig.setup({
  ensure_installed = {
    "lua_ls",
    "gopls",
    "ts_ls",
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
  },
  automatic_enable = false,
})

-- インストール済みのサーバーのみを設定
-- get_available_servers()ではなくget_installed_servers()を使用することで、
-- インストールされていないサーバーの設定ファイルが読み込まれることを防ぐ
for _, server_name in ipairs(mason_lspconfig.get_installed_servers()) do
  -- glintはcmd関数でconfigパラメータを必要とするが、Neovim 0.11の新しいLSP設定システムでは
  -- 正しく渡されないため、スキップする（Ember/Glimmerプロジェクトで必要な場合は個別設定が必要）
  if server_name ~= "glint" then
    configure(server_name)
  end
end

-- mason管理外のサーバーも個別設定
configure("typos_lsp", {
  init_options = {
    config = vim.fn.expand("~/.config/nvim/spell/.typos.toml"),
  },
})

-- Pylsp サーバー設定（E501抑制）
configure("pylsp", {
  settings = {
    pylsp = {
      plugins = {
        pycodestyle = {
          ignore = { "E501" },
        },
      },
    },
  },
})

-- Ruff LSP サーバー設定（フォーマット + リンティング）
-- ruff または ruff-lsp がインストールされている場合に有効化
local ruff_available = false
for _, installed_server in ipairs(mason_lspconfig.get_installed_servers()) do
  if installed_server == "ruff" or installed_server == "ruff_lsp" then
    ruff_available = true
    break
  end
end

if ruff_available then
  configure("ruff", {
    init_options = {
      settings = {
        -- Ruff のリンティング設定
        lint = {
          enable = true,
          ignore = { "E501" },
        },
        -- フォーマット設定
        format = {
          docstring_code_format = true,
        },
      },
    },
  })
end
