-- https://github.com/stevearc/conform.nvim
return {
  "stevearc/conform.nvim",

  event = "BufWritePre",
  cmd = "ConformInfo",

  keys = {
    {
      "<leader>cf",
      function()
        require("conform").format({ async = true, lsp_fallback = true })
      end,
      desc = "Format Buffer",
    },
  },

  config = function()
    require("conform").setup({
      formatters_by_ft = {
        typescript = { "prettier", "deno_fmt" },
        javascript = { "prettier" },
        typescriptreact = { "prettier" },
        javascriptreact = { "prettier" },
        lua = { "stylua" },
        terraform = { "terraform_fmt" },
        bash = { "shfmt" },
        sh = { "shfmt" },
        python = { "black", "isort", "ruff" },
        rust = { "rustfmt", lsp_format = "fallback" },
        go = { "gofmt", "goimports", "gofumpt" },
        yaml = { "prettier" },
        json = { "prettier" },
        markdown = { "prettier" },
      },
      format_on_save = { timeout_ms = 500, lsp_fallback = true },
    })
  end,
}
