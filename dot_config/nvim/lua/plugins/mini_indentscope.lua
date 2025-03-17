-- https://github.com/echasnovski/mini.indentscope

return {
  'echasnovski/mini.indentscope',

  config = function()
    require('mini.indentscope').setup({
      symbol = '▏',
    })
  end,

  event = 'UIEnter',
}
