-- https://github.com/keaising/im-select.nvim.git

-- Japanese Input Source
return {
	'keaising/im-select.nvim',
	opts = function()
		require('im_select').setup {
			default_im_select = 'com.apple.keylayout.ABC'
		}
	end
}

