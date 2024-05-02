-- setting of nvim-lspconfig
--[[
local on_attach = function(client, bufnr)
	local set = vim.api.nvim_set_keymap

	set("n", "gd", "<cmd>lua vim.lsp.buf.definition()<CR>", {noremap = true, silent = true})
	set("n", "K", "<cmd>lua vim.lsp.buf.hover()<CR>", {noremap = true, silent = true})
	set("n", "<space>h", "<cmd>lua vim.lsp.buf.signature_help()<CR>", {noremap = true, silent = true})
	set("n", "gy", "<cmd>lua vim.lsp.buf.type_definition()<CR>", {noremap = true, silent = true})
	set("n", "rn", "<cmd>lua vim.lsp.buf.rename()<CR>", {noremap = true, silent = true})
	set("n", "ma", "<cmd>lua vim.lsp.buf.code_action()<CR>", {noremap = true, silent = true})
	set("n", "gr", "<cmd>lua vim.lsp.buf.references()<CR>", {noremap = true, silent = true})
	set("n", "<space>e", "<cmd>lua vim.lsp.diagnostic.show_line_diagnostics()<CR>", {noremap = true, silent = true})
	set("n", "[d", "<cmd>lua vim.lsp.diagnostic.goto_prev()<CR>", {noremap = true, silent = true})
	set("n", "]d", "<cmd>lua vim.lsp.diagnostic.goto_next()<CR>", {noremap = true, silent = true})
end

local capabilities = require("cmp_nvim_lsp").default_capabilities()
require("mason").setup()
require("mason-lspconfig").setup()
require("mason-lspconfig").setup_handlers {
	function (server_name) 
		require("lspconfig")[server_name].setup {
			on_attach = on_attach, 
			capabilities = capabilities, 
		}
	end,
} ]]
