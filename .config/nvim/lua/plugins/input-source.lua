-- https://github.com/keaising/im-select.nvim.git

-- Japanese Input Source
return {
	'keaising/im-select.nvim',
	config = function()
		require('im_select').setup {
			default_im_select = 'com.apple.keylayout.ABC'
		}
	end,
	-- TODO
	ft = {
		'go',
		'javascript',
		'javascriptreact',
		'typescript',
		'typescriptreact',
		'vue',
		'html',
		'css',
		'json',
		'yaml',
		'lua',
		'python',
		'rust',
		'java',
		'c',
		'cpp',
		'php',
		'ruby',
		'vim',
		'sql',
		'bash',
		'zsh',
		'fish',
		'md',
		'markdown',
	}
}

