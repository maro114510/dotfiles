-- https://github.com/akinsho/toggleterm.nvim.git

return {
  -- terminal usage
  "akinsho/toggleterm.nvim",

  version = "*",

  config = function()
    require("toggleterm").setup({
      open_mapping = [[<c-\>]],
      shade_filetypes = {},
      shade_terminals = true,
      shading_factor = 1,
      start_in_insert = true,
      insert_mappings = true,
      persist_size = true,
      direction = "horizontal",
      on_open = function(term)
        -- ESCでターミナルモードからノーマルモードへ
        vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", { buffer = term.bufnr, noremap = true, silent = true })
      end,
    })
  end,

  cmd = "ToggleTerm",
}
