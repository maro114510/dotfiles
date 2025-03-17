-- https://github.com/kazhala/close-buffers.nvim.git
-- Close hidden buffers

return {
  'kazhala/close-buffers.nvim',

  config = function()
    require('close_buffers').delete({ type = 'hidden', force = true })
    require('close_buffers').delete({ type = 'nameless' })
  end,

  cmd = { 'BDelete' },
}
