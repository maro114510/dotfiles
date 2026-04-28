return {
  "keaising/im-select.nvim",

  -- macOS is handled by config.ime. macism can write diagnostics to stderr,
  -- which im-select.nvim captures as part of the saved input source.
  enabled = function()
    return vim.fn.has("macunix") == 0
  end,

  lazy = false,
  config = function()
    require("im_select").setup({
      set_default_events = { "InsertLeave", "CmdlineLeave" },
      set_previous_events = { "InsertEnter" },
      keep_quiet_on_no_binary = true,
      async_switch_im = false,
    })
  end,
}
