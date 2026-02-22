-- Change Color Scheme
-- vim.cmd[[colorscheme tokyonight-night]]
-- nightfox, dayfox, dawnfox, duskfox, nordfox,terafox, carbonfox
vim.cmd([[colorscheme duskfox]])

-- when leave cursor setting
vim.cmd([[
	augroup RestoreCursorShapeOnExit
		autocmd!
		autocmd VimLeave * set guicursor=a:hor1
	augroup END
]])

local theme_override_group = vim.api.nvim_create_augroup("ThemeOverrides", { clear = true })

local function apply_theme_overrides()
	if vim.g.colors_name == "duskfox" then
		vim.cmd([[highlight Normal ctermbg=NONE guibg=NONE]])
		vim.cmd([[highlight Comment cterm=italic gui=italic guifg=#ffd700 ctermfg=226]])
	end
end

vim.api.nvim_create_autocmd("ColorScheme", {
	group = theme_override_group,
	callback = apply_theme_overrides,
})

apply_theme_overrides()
