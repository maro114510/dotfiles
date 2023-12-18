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
	--
	-- Input install source
	use 'folke/tokyonight.nvim'
	use 'keaising/im-select.nvim'
	use {
		'nvim-lualine/lualine.nvim',
		requires = { 'nvim-tree/nvim-web-devicons', opt = true }
	}
	use('nvim-tree/nvim-web-devicons')
	use('kdheepak/tabline.nvim')
	use('echasnovski/mini.indentscope')
	use({
		'nvim-treesitter/nvim-treesitter',
		run = ':TSUpdate',
		highlight = {
			enable = true,
		},

	})

--	use {
--		'nvim-neo-tree/neo-tree.nvim',
--		branch = 'v2.x',
--		requires = {
--			'nvii-lua/plenary.nvim',
--			'nvim-tree/nvim-web-devicons', -- not strictly required, but recommended
--			'MunifTanjim/nui.nvim',
--		}
--	}
	use 'preservim/nerdtree'
	use 'ryanoasis/vim-devicons'

	-- ====== Appearance ======
	-- bufferline
	use {'akinsho/bufferline.nvim', tag = "*", requires = 'nvim-tree/nvim-web-devicons'}
	-- color scheme
	use 'shaunsingh/nord.nvim'
	-- use 'kristijanhusak/defx-icons'
	use 'bryanmylee/vim-colorscheme-icons'
	use {
		'neoclide/coc.nvim',
		branch = 'release'
	}

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
	-- use({ "iamcco/markdown-preview.nvim", run = "cd app && npm install", setup = function() vim.g.mkdp_filetypes = { "markdown" } end, ft = { "markdown" }, })

	-- terminal usage
	use {"akinsho/toggleterm.nvim", tag = '*', config = function()
		require("toggleterm").setup()
		end
	}

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
	-- use { 'fatih/vim-go', opt = true, ft = { 'go' } }
	use ({
		'nvimdev/lspsaga.nvim',
		after = 'nvim-lspconfig',
		config = function()
			require('lspsaga').setup({})
		end,
	})
	use 'tpope/vim-commentary'
end)

