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
local function configure(server_name, opts)
  local config = vim.tbl_deep_extend("force", {
    on_attach = on_attach,
    capabilities = capabilities,
  }, opts or {})

  vim.lsp.config[server_name] = config
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
  --ensure_installed = { "lua_ls", "tsserver", "rust_analyzer", "gopls"},
  automatic_enable = false,
})

for _, server_name in ipairs(mason_lspconfig.get_available_servers()) do
  configure(server_name)
end

-- mason管理外のサーバーも個別設定
configure("typos_lsp", {
  init_options = {
    config = vim.fn.expand("~/.config/nvim/spell/.typos.toml"),
  },
})
