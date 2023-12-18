-- Install plugin
local ensure_packer = function()
	local fn = vim.fn
	local install_path = fn.stdpath('data')..'/site/pack/packer/start/packer.nvim'
	if fn.empty(fn.glob(install_path)) > 0 then
		fn.system({'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path})
		vim.cmd [[packadd packer.nvim]]
		return true
	end
	return false
end

local packer_bootstrap = ensure_packer()

vim.cmd [[packadd packer.nvim]]
return require('packer').startup(function(use)
	-- Packer can manage itself
	use 'wbthomason/packer.nvim'

	-- Input source
	use 'keaising/im-select.nvim'

	-- Input completion
	use {
		'neoclide/coc.nvim',
		branch = 'release'
	}

	-- Filer
	use 'preservim/nerdtree'

	-- ====== Appearance ======
	-- theme
	use 'folke/tokyonight.nvim'
	use 'shaunsingh/nord.nvim'
	-- bufferline
	use {'akinsho/bufferline.nvim', tag = "*", requires = 'nvim-tree/nvim-web-devicons'}
	-- Icons
	use 'bryanmylee/vim-colorscheme-icons'
	use 'ryanoasis/vim-devicons'
	use('nvim-tree/nvim-web-devicons')

	-- Lua's underline status
	use {
		'nvim-lualine/lualine.nvim',
		requires = { 'nvim-tree/nvim-web-devicons', opt = true }
	}
	-- Setting tab view
	use('kdheepak/tabline.nvim')
	use('echasnovski/mini.indentscope')
	-- syntax highlight
	use({
		'nvim-treesitter/nvim-treesitter',
		run = ':TSUpdate',
		highlight = {
			enable = true,
		},
	})



	-- fzf
	use {
		'junegunn/fzf.vim',
		requires = { 'junegunn/fzf', run = ':call fzf#install()' }
	}
	use { 'ibhagwan/fzf-lua',
		-- optional for icon support
		requires = {
			'kyazdani42/nvim-web-devicons',
			'nvim-tree/nvim-web-devicons'
		}
	}

	-- move cursor match-up
	 use {
		'andymass/vim-matchup',
		setup = function()
			-- may set any options here
			vim.g.matchup_matchparen_offscreen = { method = "popup" }
		end
	}

	-- auto brackets close
	use 'cohama/lexima.vim'

	-- manage git
	use 'vim-denops/denops.vim'
	use 'lambdalisue/gin.vim'

	-- markdown preview
	use({
		"iamcco/markdown-preview.nvim",
		run = function() vim.fn["mkdp#util#install"]() end,
	})

	-- terminal usage
	use {"akinsho/toggleterm.nvim", tag = '*', config = function()
		require("toggleterm").setup()
		end
	}

	-- move cursor
	use {
		'phaazon/hop.nvim',
		branch = 'v2', -- optional but strongly recommended
		config = function()
			-- you can configure Hop the way you like here; see :h hop-config
			require'hop'.setup { keys = 'etovxqpdygfblzhckisuran' }
		end
	}

	-- LSP
	use 'neovim/nvim-lspconfig'
	use 'hrsh7th/cmp-nvim-lsp'
	use 'hrsh7th/cmp-buffer'
	use 'hrsh7th/cmp-path'
	use 'hrsh7th/cmp-cmdline'
	use 'hrsh7th/nvim-cmp'

	use 'L3MON4D3/LuaSnip'
	use 'saadparwaiz1/cmp_luasnip'
	use {
		'windwp/nvim-autopairs',
		config = function() require('nvim-autopairs').setup {} end
	}
	use ({
		'nvimdev/lspsaga.nvim',
		after = 'nvim-lspconfig',
		config = function()
			require('lspsaga').setup({})
		end,
	})
	use 'tpope/vim-commentary'
end)

