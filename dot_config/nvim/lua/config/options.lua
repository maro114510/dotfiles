
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
vim.opt.showcmd = true

-- Status Line
vim.opt.laststatus = 3

-- Search and Replace
vim.opt.hlsearch = true
vim.opt.incsearch = true
vim.opt.matchtime = 1

-- Color Scheme
vim.opt.termguicolors = true
vim.opt.background = "dark"

-- Display
-- Indent

-- Disable wrap test
vim.opt.wrap = false
-- Display tabline
vim.opt.showtabline = 2
-- highlights
vim.opt.showmatch = true
vim.opt.list = true

-- Interface
-- Opacity
vim.opt.pumblend = 20
-- Sub Columns
vim.opt.showtabline = 2
vim.opt.signcolumn = "yes"
