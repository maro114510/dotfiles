return {
  "mfussenegger/nvim-lint",
  ft = { "yaml", "markdown" },
  config = function()
    local lint = require("lint")
    
    lint.linters_by_ft = {
      yaml = { "cfn_lint" },
      markdown = { "markdownlint" },
    }
    
    -- CloudFormationファイルの自動検出
    local cfn_lint = lint.linters.cfn_lint
    cfn_lint.condition = function(ctx)
      local content = table.concat(vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false), "\n")
      return content:match("AWSTemplateFormatVersion") or content:match("Resources:")
    end
    
    -- オートコマンドでlintを実行
    vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
      group = vim.api.nvim_create_augroup("lint", { clear = true }),
      callback = function()
        lint.try_lint()
      end,
    })
  end,
}