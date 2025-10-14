local icons = require("user.icons")

-- Neovim 0.11+の新しいdiagnostic signs設定方式
vim.diagnostic.config({
	signs = {
		text = {
			[vim.diagnostic.severity.ERROR] = icons.error_icon,
			[vim.diagnostic.severity.WARN] = icons.warn_icon,
			[vim.diagnostic.severity.HINT] = icons.hint_icon,
			[vim.diagnostic.severity.INFO] = icons.info_icon,
		}
	}
})
