-- https://github.com/nvim-treesitter/nvim-treesitter.git

local languages = {
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

return {
  "nvim-treesitter/nvim-treesitter",

  build = ":TSUpdate",

  lazy = false,

  config = function()
    require("nvim-treesitter").setup({
      install_dir = vim.fn.stdpath("data") .. "/site",
    })

    -- Install parsers
    require("nvim-treesitter").install(languages)

    -- Enable treesitter highlighting for filetypes
    vim.api.nvim_create_autocmd("FileType", {
      pattern = languages,
      callback = function()
        vim.treesitter.start()
      end,
    })

    -- Enable treesitter-based indentation
    vim.api.nvim_create_autocmd("FileType", {
      pattern = languages,
      callback = function()
        vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end,
    })
  end,
}
