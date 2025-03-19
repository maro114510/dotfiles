-- https://github.com/williamboman/mason.nvim.git
-- https://github.com/williamboman/mason-lspconfig.nvim.git

return {
  -- Mason
  {
    "williamboman/mason.nvim",

    -- Config
    config = function()
      require("mason").setup()
    end,
  },

  -- Mason LSPConfig
  {
    "williamboman/mason-lspconfig.nvim",
  }
}
