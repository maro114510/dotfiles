-- https://github.com/nvim-treesitter/nvim-treesitter.git

-- Parsers to install
local parsers = {
  "go",
  "lua",
  "rust",
  "toml",
  "typescript",
  "javascript",
  "tsx",
  "yaml",
  "vim",
  "vimdoc",
  "html",
  "css",
  "json",
  "markdown",
  "markdown_inline",
  "terraform",
  "hcl",
  "python",
}

-- Filetypes to enable treesitter highlighting
local filetypes = {
  "go",
  "lua",
  "rust",
  "toml",
  "typescript",
  "javascript",
  "typescriptreact",
  "javascriptreact",
  "yaml",
  "vim",
  "help",
  "html",
  "css",
  "json",
  "markdown",
  "terraform",
  "hcl",
  "python",
}

return {
  "nvim-treesitter/nvim-treesitter",

  build = ":TSUpdate",

  lazy = false,

  config = function()
    -- Install parsers and queries to site/ directory
    -- This is a no-op if already installed
    require("nvim-treesitter").install(parsers)

    -- Enable treesitter highlighting and indentation
    vim.api.nvim_create_autocmd("FileType", {
      pattern = filetypes,
      callback = function()
        pcall(vim.treesitter.start)
        vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end,
    })
  end,
}
