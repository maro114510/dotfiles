-- https://github.com/neovim/nvim-lspconfig.git
-- Collection of common configurations for the Nvim LSP client

return {
  "neovim/nvim-lspconfig",
  lazy = false,
  config = function()
    settings = {
      Lua = {
        diagnostics = {
          globals = { "vim" },
        },
      }
    }
  end
}
