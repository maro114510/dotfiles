-- https://github.com/rmagatti/auto-session.git

return {
	'rmagatti/auto-session',
	opt = function()
		require("auto-session").setup {
			log_level = "error",
			auto_session_suppress_dirs = { "~/", "~/Projects", "~/Downloads", "/"},
			auto_session_enable_last_session = true,
		}
	end,
	lazy = true,
}
