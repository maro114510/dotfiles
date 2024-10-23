
local wezterm = require 'wezterm'
local act = wezterm.action

local mod = {}

mod.SUPER = 'SUPER'
mod.SUPER_REV = 'SUPER|CTRL'

local keys = {
	-- copy/paste --
	{ key = 'c', mods = 'CTRL|SHIFT', action = act.CopyTo('Clipboard') },
	{ key = 'v', mods = 'CTRL|SHIFT', action = act.PasteFrom('Clipboard') },

	-- close window with 1sec cmd + w
	{ key = 'w', mods = 'CMD', action = act.CloseCurrentTab { confirm = true } },
	-- window --
	-- spawn window
	{ key = 'n', mods = mod.SUPER, action = act.SpawnWindow },
	-- panes --
	-- split
	{
		key = [[\]],
		mods = mod.SUPER_REV,
		action = act.SplitHorizontal({ domain = 'CurrentPaneDomain' }),
	},
	{ key = 'k', mods = mod.SUPER_REV, action = act.ActivatePaneDirection('Up') },
	{ key = 'j', mods = mod.SUPER_REV, action = act.ActivatePaneDirection('Down') },
	{ key = 'h', mods = mod.SUPER_REV, action = act.ActivatePaneDirection('Left') },
	{ key = 'l', mods = mod.SUPER_REV, action = act.ActivatePaneDirection('Right') },
	{
		key = 'f',
		mods = 'SHIFT|META',
		action = wezterm.action.ToggleFullScreen,
	},
	-- Ctrl+Shift+d create new pane
	{
		key = 'd',
		mods = 'SHIFT|CMD',
		action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' },
	},
}

wezterm.font {
	-- family = 'font-anonymice-nerd-font'
	family = 'font-Hack-nerd-font'
}

-- local home = os.getenv( "HOME" )
-- local background_path = home .. '/.config/wezterm/config/background.jpg'

---@class Config
---@field options table
local Config = {
	animation_fps = 60,
	max_fps = 60,
	front_end = 'WebGpu',
	webgpu_power_preference = 'HighPerformance',

	-- color_scheme = 'tokyonight_night',
	color_scheme = 'Molokai',
	-- color_scheme = 'tokyonight_storm',
	window_background_opacity = 0.85,
	macos_window_background_blur = 15,
	hide_tab_bar_if_only_one_tab = true,

	-- cursor
	default_cursor_style = 'SteadyUnderline',

	-- background
	-- background_image = background_path,
	-- scrollbar
	enable_scroll_bar = true,

	-- hide_tab_bar_if_only_one_tab = true,

	-- window
	-- window_background_image = background_path,
	-- inactive_pane_hsb = { saturation = 1.0, brightness = 1.0 },
	leader = { key = 'Space', mods = 'CTRL|SHIFT' },
	keys = keys,

	macos_forward_to_ime_modifier_mask = "SHIFT|CTRL",

	use_ime = true
}

return Config
