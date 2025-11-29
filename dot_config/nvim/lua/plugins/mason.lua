-- https://github.com/williamboman/mason.nvim.git
-- https://github.com/williamboman/mason-lspconfig.nvim.git

return {
  -- Mason
  {
    "williamboman/mason.nvim",
    dependencies = { 'mason-org/mason-registry' },

    -- Config
    config = function()
      require("mason").setup()
    end,

    cmd = { "Mason" },
  },

  -- Mason LSPConfig
  {
    "williamboman/mason-lspconfig.nvim",
  }
}
