-- https://github.com/stevearc/conform.nvim
return {
  "stevearc/conform.nvim",

  event = "BufWritePre",
  cmd = "ConformInfo",

  keys = {
    {
      "<leader>cf",
      function()
        require("conform").format({ async = true, lsp_format = "fallback" })
      end,
      desc = "Format Buffer",
    },
  },

  config = function()
    local external_formatter_filetypes = {
      go = true,
      javascript = true,
      javascriptreact = true,
      python = true,
      typescript = true,
      typescriptreact = true,
    }

    require("conform").setup({
      formatters_by_ft = {
        typescript = { "prettierd" },
        javascript = { "prettierd" },
        typescriptreact = { "prettierd" },
        javascriptreact = { "prettierd" },
        lua = { "stylua" },
        terraform = { "terraform_fmt" },
        bash = { "shfmt" },
        sh = { "shfmt" },
        python = { "ruff_organize_imports", "ruff_format" },
        rust = { "rustfmt", lsp_format = "fallback" },
        go = { "goimports", "gofumpt" },
        yaml = { "prettierd" },
        json = { "prettierd" },
        markdown = { "prettierd" },
        sql = { "sql_formatter" },
        kotlin = { "ktlint" },
        swift = { "swift_format" },
      },
      format_on_save = function(bufnr)
        local filetype = vim.bo[bufnr].filetype
        return {
          timeout_ms = 500,
          lsp_format = external_formatter_filetypes[filetype] and "never" or "fallback",
        }
      end,
    })
  end,
}
