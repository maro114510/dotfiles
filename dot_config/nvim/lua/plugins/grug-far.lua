-- https://github.com/DNLHC/glance.nvim.git
-- Replace this with the contents of the README.md file

return {
  "MagicDuck/grug-far.nvim",

  cmd = { "GrugFar" },

  config = function()
    require("grug-far").setup({
      -- options, see Configuration section below
      -- there are no required options atm
      -- engine = 'ripgrep' is default, but 'astgrep' can be specified
    })
  end,
}
