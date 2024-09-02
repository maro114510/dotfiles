-- https://github.com/neovim/nvim-lspconfig.git

return {
	'neovim/nvim-lspconfig',

	event = { "VimEnter" },

	dependencies = {
		{ 'williamboman/mason.nvim', config = true },
		'williamboman/mason-lspconfig.nvim',
		'folke/neodev.nvim',
		'jose-elias-alvarez/null-ls.nvim',
	},
	config = function()
		local on_attach = function(_, bufnr)
			local nmap = function(keys, func, desc)
				if desc then
					desc = "LSP: " .. desc
				end

				vim.keymap.set(
					"n",
					keys,
					func,
					{ buffer = bufnr, description = desc }
					{ buffer = bufnr, noremap = true, silent = true, desc = desc }
				)
			end

			nmap("gd", vim.lsp.buf.definition, "[G]oto [D]efinition")
			nmap("K", vim.lsp.buf.hover, "[K] [H]over")
			nmap("gr", vim.lsp.buf.references, "[G]oto [R]references")
			nmap("gI", vim.lsp.buf.implementation, "[G]oto [I]mplementation")
			nmap("rnm", vim.lsp.buf.rename, "[R]rename [N]ame")

			nmap("<space>D", vim.lsp.buf.type_definition, "[D]efinition")
			-- nmap("gD", vim.lsp.buf.declearation, "[G]oto [D]eclaration")

			nmap("<space>wl", function()
				print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
			end, "[W]orkspace [L] list")

			vim.api.nvim_buf_create_user_command(
				bufnr,
				"Format",
				function(_)
					vim.lsp.buf.format()
				end, { desc = "Format the current buffer"}
			)
		end

		require("neodev").setup()

		local servers = {
			lua_ls = {
				Lua = {
					workspace = { checkThirdParty = false },
					telemetry = { enable = false },
				},
			},
			tsserver = {},
		}

		local capabilities = vim.lsp.protocol.make_client_capabilities()
		capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)

		local mason_lspconfig = require("mason-lspconfig")
		mason_lspconfig.setup{
			ensure_installed = vim.tbl_keys(servers),
		}

		mason_lspconfig.setup_handlers {
			function(server_name)
				require("lspconfig")[server_name].setup {
					on_attach = on_attach,
					capabilities = capabilities,

					settings = servers[server_name],
					filetypes = (servers[server_name] or {}).filetypes,
				}
			end
		}

		-- Prettier を null-ls を通して利用するようにする
		local null_ls = require("null-ls")
		null_ls.setup({
			sources = {
				null_ls.builtins.formatting.prettier,
			},
			on_attach = on_attach,
		})

		require("lspconfig").tsserver.setup {
			on_attach = on_attach,
			capabilities = capabilities,
		}
		require("lspconfig").typos_lsp.setup {}
		require("lspconfig").gopls.setup {
			on_attach = on_attach,
			capabilities = capabilities,
		}
	end,
}
