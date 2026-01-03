-- https://github.com/nvzone/menu

return {
  { "nvzone/volt" , lazy = true },
  { "nvzone/menu" , lazy = true },

  vim.api.nvim_set_keymap('n', '<C-m>', ':lua require("menu").menu("default")<CR>', { noremap = true, silent = true }),
}
