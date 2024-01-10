--[[ local act = require "wezterm".action

config.keys = {
	{
		mods = 'LEADER',
		key = 's',
		action = act.ShowLauncherArgs { flags = 'WORKSPACES' , title = "Select workspace" },
	},
}

return {

} ]]
