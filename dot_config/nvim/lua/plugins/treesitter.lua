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
  "kotlin",
  "swift",
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
  "kotlin",
  "swift",
}

return {
  "nvim-treesitter/nvim-treesitter",

  build = ":TSUpdate",

  event = "BufReadPost",

  opts = {
    ensure_installed = parsers,
  },

  config = function(_, opts)
    require("nvim-treesitter").setup(opts)

    local group = vim.api.nvim_create_augroup("UserTreesitterFeatures", { clear = true })
    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      pattern = filetypes,
      callback = function(args)
        local ok_start = pcall(vim.treesitter.start, args.buf)
        if ok_start then
          vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end,
    })
  end,
}
