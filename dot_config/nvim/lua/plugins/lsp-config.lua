-- https://github.com/neovim/nvim-lspconfig.git
-- Collection of common configurations for the Nvim LSP client

return {
  "neovim/nvim-lspconfig",

  event = { "BufReadPre", "BufNewFile" },

  config = function()
    local settings = {
      Lua = {
        diagnostics = {
          globals = { "vim" },
        },
      }
    }
  end
}
