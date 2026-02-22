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
    local ts = require("nvim-treesitter")
    -- NOTE: Parser compilation uses `tree-sitter build`, so tree-sitter CLI
    -- must be installed and available in Neovim's PATH.

    local installed = {}
    local ok_installed, installed_list = pcall(ts.get_installed, "parsers")
    if ok_installed and type(installed_list) == "table" then
      for _, lang in ipairs(installed_list) do
        installed[lang] = true
      end
    end

    local missing = {}
    for _, lang in ipairs(parsers) do
      if not installed[lang] then
        table.insert(missing, lang)
      end
    end

    if #missing > 0 then
      pcall(ts.install, missing)
    end

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
