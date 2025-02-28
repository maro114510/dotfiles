local icons = require("user.icons")

local signs = {
	Error = icons.error_icon,
	Warn = icons.warn_icon,
	Hint = icons.hint_icon,
	Info = icons.info_icon,
	Todo = icons.todo_icon,
}
for type, icon in pairs(signs) do
    local hl = "DiagnosticSign" .. type
    vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
end
