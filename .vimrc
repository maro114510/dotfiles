
" ===== fileoption =====
" priority of file encoding
set fileencodings=utf-8,cp932,sjis
" file encoding
set encoding=utf-8
" indicate file formant
set fileformat=unix

" ===== memo =====
" line number
set number
" show invisible character
set list 
" show window title
set title
" show statusline
set laststatus=2 
" show cursor
set ruler
" double width character
set ambiwidth=double
" syntax highlight
syntax on 

" ===== figure =====
" auto indent
set autoindent
set smartindent
" tabsize
set tabstop=4
set shiftwidth=4
set expandtab

"===== search =====
" search ignore upper-case lower-case character
set ignorecase
" return to start, when reach end
set wrapscan 
" highlight word
set hlsearch
" increment
set incsearch

" ===== blackets =====
inoremap ( ()<left>
inoremap [ []<left>
inoremap { {}<left>
inoremap " ""<left>
inoremap ' ''<left>

" ===== others =====
" number of history is 300
set history=300
" using global clipboard
set clipboard+=unnamed
" disaple backupfile
set nobackup
" disaple swapfile
set noswapfile
set autoread

" ===== plugin settings =====
autocmd VimEnter * NERDTree | wincmd p
let NERDTreeShowHidden=1

" ===== editing settings =====
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
	" plugin managr
	Jetpack 'tani/vim-jetpack', {'opt': 1} "bootstrap
	" vim indent guides
	Jetpack 'nathanaelkane/vim-indent-guides'
	" fuzzy file search
	Jetpack 'junegunn/fzf', { 'do': { -> fzf#install() } }
	Jetpack 'junegunn/fzf.vim'
	" using git
	Jetpack 'tpope/vim-fugitive'
	" move fast
	Jetpack 'unblevable/quick-scope'
	" nerdtree
	Jetpack 'preservim/nerdtree'
call jetpack#end()

