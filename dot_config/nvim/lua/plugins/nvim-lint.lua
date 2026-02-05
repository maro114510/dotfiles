-- https://github.com/mfussenegger/nvim-lint

return {
  "mfussenegger/nvim-lint",

  ft = { "yaml" },

  config = function()
    local lint = require("lint")

    lint.linters_by_ft = { yaml = {} }

    local function is_cfn_yaml(bufnr)
      local name = vim.api.nvim_buf_get_name(bufnr or 0)
      if name == "" then
        return false
      end

      name = name:gsub("\\", "/")
      local lower = name:lower()

      if not lower:match("%.ya?ml$") then
        return false
      end

      if lower:match("/cfn/") or lower:match("/cloudformation/") then
        return true
      end

      local basename = lower:match("([^/]+)$") or lower
      if basename == "template.yaml" or basename == "template.yml" then
        return true
      end

      return false
    end

    vim.api.nvim_create_autocmd("BufReadPost", {
      pattern = { "*.yaml", "*.yml" },
      callback = function(args)
        if not is_cfn_yaml(args.buf) then
          return
        end

        local cur = vim.api.nvim_get_current_buf()
        if cur ~= args.buf then
          vim.api.nvim_set_current_buf(args.buf)
        end

        lint.try_lint("cfn_lint")

        if cur ~= args.buf then
          vim.api.nvim_set_current_buf(cur)
        end
      end,
    })
  end,
}
