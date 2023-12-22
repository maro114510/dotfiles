
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
-- vim.opt.backspace = 'start', 'eol', 'indent'

-- Indent
vim.o.autoindent = true
vim.o.smartindent = true
vim.o.expandtab = false
vim.o.tabstop = 4
vim.o.shiftwidth = 4

-- Nerd tree
vim.g.NERDTreeShowHidden = 1

-- coc
vim.g.coc_global_extensions = {
	'coc-flutter',
	'coc-cmake',
	'coc-sh',
	'coc-python',
	'coc-html',
	'coc-sql',
	'coc-go',
	'coc-rls',
	'coc-tsserver',
	'coc-docker',
	'coc-yaml',
	'coc-markdownlint',
	'coc-xml',
	'coc-css',
	'coc-json',
	'coc-vimlsp',
	'coc-spell-checker',
}

-- Link to clipboard
vim.opt.clipboard:append { 'unnamed', 'unnamedplus' }

-- Able to mouse
vim.opt.mouse = 'a'

-- Visualization of control characters
vim.opt.list = true
vim.opt.listchars = {
	tab = '→-',
	extends = '⟩',
	precedes = '⟨',
	trail = '·',
	eol = '↴',
	nbsp = '%'
}
