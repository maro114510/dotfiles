
set fileencodings=utf-8,cp932,sjis
set encoding=utf-8
set fileformat=unix

"===== memo =====
set number " line number
set list " display
set title " view title
set laststatus=2 " display status
set ruler " display cursor
set ambiwidth=double
syntax on " syntax highlight

"===== figure =====
set autoindent
set smartindent
set tabstop=4
set shiftwidth=4
set expandtab

"===== search =====
set ignorecase
set wrapscan " return to start if reach end
set hlsearch " enhance word
set incsearch

"===== blackets =====
inoremap ( ()<left>
inoremap [ []<left>
inoremap { {}<left>
inoremap " ""<left>
inoremap ' ''<left>

"===== others =====
set history=300
set clipboard+=unnamed
set nobackup
set noswapfile
set autoread

"===== plugin settings =====
autocmd VimEnter * NERDTree | wincmd p
let NERDTreeShowHidden=1

" Delete without yanking
nnoremap x "_x
nnoremap s "_s
nnoremap d "_d
nnoremap D "_D
xnoremap d "_d

" Map 'jj' to <Esc> in insert mode
inoremap jj <Esc>

" Exchange ;:
noremap ; :

"===== Vim-jetpack =====
packadd vim-jetpack
call jetpack#begin()
	Jetpack 'tani/vim-jetpack', {'opt': 1} "bootstrap
	Jetpack 'nathanaelkane/vim-indent-guides'
	Jetpack 'junegunn/fzf', { 'do': { -> fzf#install() } }
	Jetpack 'junegunn/fzf.vim'
	Jetpack 'nathanaelkane/vim-indent-guides'
	Jetpack 'tpope/vim-fugitive'
	Jetpack 'preservim/nerdtree'
call jetpack#end()

