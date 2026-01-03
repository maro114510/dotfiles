-- https://github.com/coder/claudecode.nvim.git

return {
  "coder/claudecode.nvim",

  dependencies = { "folke/snacks.nvim" },

  config = true,

  keys = {
    { "<C-c><C-c>", "<cmd>ClaudeCode<CR>", mode = { "n", "v" } },
    { "<leader>ar", "<cmd>ClaudeCode --resume<cr>", desc = "Resume Claude" },
    -- Diff management
    { "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept diff" },
    { "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Deny diff" },
  },
}
