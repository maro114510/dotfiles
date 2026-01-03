-- https://github.com/nvim-treesitter/nvim-treesitter.git

return {
  "nvim-treesitter/nvim-treesitter",

  build = ":TSUpdate",

  event = { "BufReadPost", "BufNewFile" },

  config = function()
    require("nvim-treesitter.configs").setup({
      auto_tag = {
        enable = true,
      },

      auto_install = true,

      highlight = {
        enable = true,
      },

      indent = {
        enable = true,
      },

      ensure_installed = {
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
      },

      notify = false,
    })
  end,

  ft = {
    "go",
    "lua",
    "rust",
    "toml",
    "typescript",
    "yaml",
    "javascript",
    "tsx",
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
  },
}
