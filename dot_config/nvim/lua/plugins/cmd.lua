-- https://github.com/hrsh7th/cmp-nvim-lsp.git

return {
    {
		'hrsh7th/cmp-nvim-lsp',
		event = 'BufRead',
    },
    {
        'hrsh7th/cmp-buffer',
        event = 'BufRead',
    },
    {
        'hrsh7th/cmp-path',
        event = 'BufRead',
    },
    {
        'hrsh7th/cmp-cmdline',
        event = 'CmdlineEnter',
    },
    {
        'hrsh7th/nvim-cmp',
        event = 'InsertEnter',
    },
}
