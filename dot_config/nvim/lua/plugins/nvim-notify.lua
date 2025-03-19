-- https://github.com/rcarriga/nvim-notify

return {
  'rcarriga/nvim-notify',

  config = function()
    local notify = require('notify')
      notify.setup({
        -- Animation style (see below for details)
        animation_style = 'slide',

        max_width = 50,
        timeout = 1000,

        background_colour = '#282c34',
      })

    vim.notify = notify
  end,

  event = 'UIEnter',
}
