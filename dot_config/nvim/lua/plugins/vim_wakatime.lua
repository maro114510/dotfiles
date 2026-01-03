-- https://github.com/wakatime/vim-wakatime.git

return {
  "wakatime/vim-wakatime",

  lazy = false,

  setup = function()
    vim.cmd([[packadd wakatime/vim-wakatime]])
  end,
}
