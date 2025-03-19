-- https://github.com/kevinhwang91/nvim-hlslens.git
-- nvim-hlslens helps you better glance at matched information, seamlessly jump between matched instances.

return {
  "kevinhwang91/nvim-hlslens",

  config = function()
    require("scrollbar.handlers.search").setup({
      -- hlslens config overrides
    })
  end,
}
