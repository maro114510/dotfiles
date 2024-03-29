local status, alpha = pcall(require, "alpha")
if not status then
	return
end

local dashboard = require("alpha.themes.dashboard")

dashboard.section.header.val = {
	"          ,--.              ,----..                                 ____    ",
	"        ,--.'|    ,---,.   /   /   \\                 ,---,        ,'  , `.  ",
	"    ,--,:  : |  ,'  .' |  /   .     :        ,---.,`--.' |     ,-+-,.' _ |  ",
	" ,`--.'`|  ' :,---.'   | .   /   ;.  \\      /__./||   :  :  ,-+-. ;   , ||  ",
	" |   :  :  | ||   |   .'.   ;   /  ` ; ,---.;  ; |:   |  ' ,--.'|'   |  ;|  ",
	" :   |   \\ | ::   :  |-,;   |  ; \\ ; |/___/ \\  | ||   :  ||   |  ,', |  ':  ",
	" |   : '  '; |:   |  ;/||   :  | ; | '\\   ;  \\ ' |'   '  ;|   | /  | |  ||  ",
	" '   ' ;.    ;|   :   .'.   |  ' ' ' : \\   \\  \\: ||   |  |'   | :  | :  |,  ",
	" |   | | \\   ||   |  |-,'   ;  \\; /  |  ;   \\  ' .'   :  ;;   . |  ; |--'   ",
	" '   : |  ; .''   :  ;/| \\   \\  ',  /    \\   \\   '|   |  '|   : |  | ,      ",
	" |   | '`--'  |   |    \\  ;   :    /      \\   `  ;'   :  ||   : '  |/       ",
	" '   : |      |   :   .'   \\   \\ .'        :   \\ |;   |.' ;   | |`-'        ",
	" ;   |.'      |   | ,'      `---`           '---' '---'   |   ;/            ",
	" '---'        `----'                                      '---'             ",
}

-- Set menu
dashboard.section.buttons.val = {
	dashboard.button("n", "  New file", ":ene <BAR> startinsert <CR>"),
	dashboard.button("r", "  Recent file", ":Telescope smart_open <CR>"),
	dashboard.button("f", "󰥨  Find file", ":Telescope find_files find_command=rg,--files,--hidden,--glob,!*.git<CR>"),
	dashboard.button("g", "󰱼  Find text", ":Telescope live_grep <CR>"),
	dashboard.button('l', '󰒲  Lazy', ':Lazy<CR>'),
	dashboard.button("q", "  Quit", ":qa<CR>"),
}

-- Set footer
local function footer()
	local datetime = os.date(" %Y-%m-%d   %H:%M:%S")
	local version = vim.version()
	local version_info = "   v" .. version.major .. "." .. version.minor .. "." .. version.patch
	return datetime .. "  ⚡" .. " plugins" .. version_info
end

dashboard.section.footer.val = footer()

-- Send config to alpha
alpha.setup(dashboard.opts)

-- Disable folding on alpha buffer
vim.cmd([[autocmd FileType alpha setlocal nofoldenable]])

