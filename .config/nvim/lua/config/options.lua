
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
vim.opt.termguicolors = true
vim.opt.background = "dark"

-- Display
-- Indent
vim.o.smartindent = true
vim.o.list = true
vim.o.listchars = 'tab:>>-,trail:-'
vim.api.nvim_set_option('termguicolors', true)
vim.opt.winblend = 20

-- Disable wrap test
vim.opt.wrap = true
-- Display tabline
vim.opt.showtabline = 2 
-- highlights
vim.opt.showmatch = true
vim.opt.list = true
vim.opt.listchars = { tab = '>>', trail = '-', nbsp = '+' }

-- Interface
-- Opacity
vim.opt.winblend = 20
-- Opacity
vim.opt.pumblend = 20
-- Sub Coloums
vim.opt.showtabline = 2
vim.opt.signcolumn = "yes"

