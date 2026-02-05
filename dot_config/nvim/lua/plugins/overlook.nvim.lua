-- https://github.com/WilliamHsieh/overlook.nvim

return {
  "WilliamHsieh/overlook.nvim",

  event = "LspAttach",

  keys = {
    { "<leader>pd", function() require("overlook.api").peek_definition() end, desc = "Peek Definition" },
    { "<leader>pc", function() require("overlook.api").close_all() end, desc = "Close All Popups" },
    { "<leader>pu", function() require("overlook.api").restore_popup() end, desc = "Restore Last Popup" },
    { "<leader>pU", function() require("overlook.api").restore_all_popups() end, desc = "Restore All Popups" },
    { "<leader>pf", function() require("overlook.api").switch_focus() end, desc = "Toggle Focus" },
    { "<leader>ps", function() require("overlook.api").open_in_split() end, desc = "Open in Split" },
    { "<leader>pv", function() require("overlook.api").open_in_vsplit() end, desc = "Open in VSplit" },
    { "<leader>po", function() require("overlook.api").open_in_original() end, desc = "Open in Original" },
  },

  opts = {
    border = "rounded",
    max_width = 100,
    max_height = 20,
  },
}
