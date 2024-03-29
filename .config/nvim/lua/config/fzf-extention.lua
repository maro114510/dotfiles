
local actions = require "fzf-lua.actions"

file_tabedit = function(selected, opts)
	actions.file_tabedit(selected, opts)
	vim.cmd("NERDTree")
	vim.cmd("wincmd p")
end

require'fzf-lua'.setup {
	actions = {
		files = {
			["default"]     = actions.file_edit_or_qf,
			["ctrl-t"]      = file_tabedit,
			["ctrl-s"]      = actions.file_split,
			["ctrl-v"]      = actions.file_vsplit,
			["alt-q"]       = actions.file_sel_to_qf,
			["alt-l"]       = actions.file_sel_to_ll,
		},
	},
}

