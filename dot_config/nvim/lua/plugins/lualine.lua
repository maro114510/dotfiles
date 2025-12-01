-- https://github.com/nvim-tree/nvim-web-devicons.git

return   {
  'nvim-lualine/lualine.nvim',

  dependencies = {
    'nvim-tree/nvim-web-devicons',

    opt = true
  },

  config = function()
    require("lualine").setup({
      options = {
        globalstatus = true,
        icons_enabled = true,
        theme = "everforest",
        section_separators = { left = "", right = "" },
        component_separators = { left = "", right = "" },
        disabled_filetypes = {},
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = {
          "branch",
          {
            "filename",
            file_status = true,
            path = 0,
          },
        },
        lualine_c = {
          {
            "diff",
            symbols = {added = ' ', modified = ' ', removed = ' '},
          }
        },
        lualine_x = {
          {
            "diagnostics",
            sources = { "nvim_lsp" },
            symbols = { error = " ", warn = " ", info = " ", hint = " " },
          },
        },
        lualine_y = { "encoding", "fileformat" },
        lualine_z = { "filetype", "searchcount" }
      },
      inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = { {
          "filename",
          file_status = true,
          path = 1,
        } },
        lualine_x = { "location" },
        lualine_y = {},
        lualine_z = {},
      },
      tabline = {},
      extensions = { "fugitive" },
    })
  end,

  event = "VeryLazy",
}
