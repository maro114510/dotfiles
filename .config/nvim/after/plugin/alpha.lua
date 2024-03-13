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
	dashboard.button("r", "  Recent file", ":FzfLua oldfiles <CR>"),
	dashboard.button("p", "󰏒  Recent file", ":Telescope frecency <CR>"),
	dashboard.button("f", "󰥨  Find file", ":FzfLua files <CR>"),
	dashboard.button("g", "󰱼  Find text", ":FzfLua live_grep <CR>"),
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

