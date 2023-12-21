vim.loader.enable()

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable", -- latest stable release
		lazypath,
	})
end

local plugins = require("plugins")

local opts = {
	checker = {
		enabled = true,
	},
	performance = {
--		cache = {
--			enabled = true,
--		},
		rtp = {
			disabled_plugins = {
				'gzip',
				'matchit',
				--'matchparen',
				--'netrwPlugin',
				'tarPlugin',
				'tohtml',
				'tutor',
				'zipPlugin',
			},
		},
	},
}


vim.opt.rtp:prepend(lazypath)
require("lazy").setup(plugins, opts)

require("lualine").setup({
	sections = {
		lualine_x = {
		{
			require("lazy.status").updates,
			cond = require("lazy.status").has_updates,
			color = { fg = "#ff9e64" },
		},
		},
	},
})

require('options')
require('lsp')
require('coc')
require('comp')
require('keymap')
require('autocmds')
require('base')
require('tterm')
require('fzf-lua-setting')
require('appearance')
