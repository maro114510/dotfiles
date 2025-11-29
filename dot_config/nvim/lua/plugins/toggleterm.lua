-- https://github.com/akinsho/toggleterm.nvim.git

return {
  -- terminal usage
  "akinsho/toggleterm.nvim",

  version = '*',

  config = function()
    require("toggleterm").setup(
      {
        open_mapping = [[<c-\>]],
        shade_filetypes = {},
        shade_terminals = true,
        shading_factor = 1,
        start_in_insert = true,
        insert_mappings = true,
        persist_size = true,
        direction = 'horizontal',
      },

      -- ESCでターミナルモードからノーマルモードへ
      function(term)
        vim.api.nvim_buf_set_keymap(
          trm.bufnr,
          "t",
          "<Esc>",
          "<C-\\><C-n>",
          {noremap = true, silent = true}
        )
      end
    )
  end,

  cmd = "ToggleTerm",
}
