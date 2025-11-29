-- https://github.com/smoka7/multicursors.nvim.git
-- Multiple cursors for vim

return {
  "smoka7/multicursors.nvim",

  dependencies = {
    'nvimtools/hydra.nvim',
  },

  opts = {},

  cmd = { 'MCstart', 'MCvisual', 'MCclear', 'MCpattern', 'MCvisualPattern', 'MCunderCursor' },

  keys = {
    {
      mode = { 'v', 'n' },
      '<Leader>m',
      '<cmd>MCstart<cr>',
      desc = 'Create a selection for selected text or word under the cursor',
    },
    {
      "<C-n>",
      mode = { "n", "v" },
      function()
        require("multicursors").start()
      end,
      desc = "Start multicursor",
    },
  },
}
