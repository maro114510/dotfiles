-- Setting Base Config
-- Show number
vim.opt.number = true

-- Error sound to visual
vim.opt.visualbell = true

-- Ignore capital
vim.opt.ignorecase = true

-- If search Capitalize
vim.opt.smartcase = true

-- If the search reeach end, from the beginning
vim.opt.wrapscan = true

-- Movin cursor
-- Moving across lines
vim.opt.whichwrap = 'b', 's', 'h', 'l', '<', '>', '[', ']'

-- Target at deletion
vim.opt.backspace = 'start', 'eol', 'indent'

-- Link to clipboard
vim.opt.clipboard:append({unnamedeplus = true})

-- Able to mouse
vim.opt.mouse = 'a'

-- Visualization of control characters
vim.opt.list = true
vim.opt.listchars = {
	tab = '│·',
	extends = '⟩',
	precedes = '⟨',
	trail = '·',
	eol = '↴',
	nbsp = '%'
}

