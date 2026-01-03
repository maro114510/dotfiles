-- https://github.com/potamides/pantran.nvim.git
-- Translate

return {
  "potamides/pantran.nvim",

  config = function()
    require("pantran").setup({
      default_engine = "google",
        engines = {
          google = {
            fallback = {
            default_source = "auto",
            default_target = "en",
          }
        }
      }
    })
  end,

  cmd = { "Pantran" },
}
