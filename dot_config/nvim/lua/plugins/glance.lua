-- https://github.com/DNLHC/glance.nvim.git
-- LSP diagnostics at a glance

return {
  "dnlhc/glance.nvim",

  keys = {
    { "gd", "<CMD>Glance definitions<CR>", desc = "Glance definitions" },
    { "gr", "<CMD>Glance references<CR>", desc = "Glance references" },
    { "gt", "<CMD>Glance type_definitions<CR>", desc = "Glance type definitions" },
    { "gi", "<CMD>Glance implementations<CR>", desc = "Glance implementations" },
  },

  config = function()
    require("glance").setup()
  end,

  ft = { "go", "python", "rust", "javascript", "typescript", "lua" },
}
