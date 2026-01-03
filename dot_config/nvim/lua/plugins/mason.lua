-- https://github.com/mason-org/mason.nvim.git
-- https://github.com/mason-org/mason-lspconfig.nvim.git

return {
  -- Mason
  {
    "mason-org/mason.nvim",
    dependencies = { "mason-org/mason-registry" },

    -- Config
    config = function()
      require("mason").setup()
    end,

    cmd = { "Mason" },
  },

  -- Mason LSPConfig
  {
    "mason-org/mason-lspconfig.nvim",
  },

  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",

    dependencies = {
      "mason-org/mason.nvim",
      "mason-org/mason-lspconfig.nvim",
    },

    event = "VeryLazy",

    opts = {
      ensure_installed = {
        "actionlint",
        "shellcheck",
        "shfmt",
        "goimports",
        "gofumpt",
        "golangci-lint",
        "prettierd",
        "typos",
        "tflint",
        "tfsec",
      },
      run_on_start = true,
    },
  },
}
