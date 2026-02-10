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
  "proto",
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
  "proto",
}

return {
  "nvim-treesitter/nvim-treesitter",

  build = ":TSUpdate",

  lazy = false,

  config = function()
    local enabled_filetypes = {}
    for _, ft in ipairs(filetypes) do
      enabled_filetypes[ft] = true
    end

    require("nvim-treesitter.configs").setup({
      ensure_installed = parsers,
      sync_install = false,
      auto_install = true,
      highlight = {
        enable = true,
        disable = function(_, bufnr)
          local ft = vim.bo[bufnr].filetype
          return not enabled_filetypes[ft]
        end,
      },
      indent = {
        enable = true,
        disable = function(_, bufnr)
          local ft = vim.bo[bufnr].filetype
          return not enabled_filetypes[ft]
        end,
      },
    })
  end,
}
