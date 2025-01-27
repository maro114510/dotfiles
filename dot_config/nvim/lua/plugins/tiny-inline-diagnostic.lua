-- https://github.com/rachartier/tiny-inline-diagnostic.nvim.git

-- https://github.com/rachartier/tiny-inline-diagnostic.nvim#%EF%B8%8F-setup
vim.diagnostic.config({ virtual_text = false })
return {
    "rachartier/tiny-inline-diagnostic.nvim",
    event = "VeryLazy", -- Or `LspAttach`
    priority = 1000, -- needs to be loaded in first
    config = function()
        require('tiny-inline-diagnostic').setup()
        vim.diagnostic.config({ virtual_text = false }) -- Only if needed in your configuration, if you already have native LSP diagnostics
    end
}
