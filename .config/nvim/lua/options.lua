-- About File
vim.opt.fileencoding = "utf-8"
vim.opt.swapfile = false -- Do not create swapfiile
vim.opt.hidden = true

-- Do not use clipboard
vim.opt.formatoptions:remove("r")
vim.opt.formatoptions:remove("o")

-- Menu and command
vim.opt.wildmenu = true
vim.opt.cmdheight = 1
vim.opt.laststatus = 2
vim.opt.showcmd = true

-- Search and Replace
vim.opt.hlsearch = true
vim.opt.incsearch = true
vim.opt.matchtime = 1

-- Color Scheme
vim.opt.termguicolors = true -- 24bit Color
vim.opt.background = "dark" -- Using dark Color

-- Display
-- Indent
vim.o.smartindent = true
vim.o.list = true
vim.o.listchars = 'tab:>>-,trail:-'

-- Disable wrap test
vim.opt.wrap = false
-- Display tabline
vim.opt.showtabline = 2 
-- highlights
vim.opt.showmatch = true
vim.opt.list = true
vim.opt.listchars = { tab = '>>', trail = '-', nbsp = '+' }

-- Interface
vim.opt.winblend = 20 -- Opacity
vim.opt.pumblend = 20 -- Popup window
vim.opt.showtabline = 2 -- subcoloumn
vim.opt.signcolumn = "yes" -- signcolumn

