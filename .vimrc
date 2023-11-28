
set fileencodings=utf-8,cp932,sjis
set encoding=utf-8
set fileformat=unix

"===== memo =====
set number "行番号の表示
set list "タブ、空白、改行を可視化
set title "編集中のファイル名を表示
set laststatus=2 "ステータスを表示
set ruler "カーソル位置を表示
set ambiwidth=double
syntax on "シンタックスハイライト

"===== 文字、カーソル設定 =====
set autoindent
set smartindent
set tabstop=4
set shiftwidth=4
set expandtab

"===== 検索設定 =====
set ignorecase "大文字小文字の区別なし
set wrapscan "検索時に最後まで行ったら最初に戻る
set hlsearch "検索した文字を強調
set incsearch "インクリメンタルサーチを有効化

"===== カッコ =====
inoremap ( ()<left>
inoremap [ []<left>
inoremap { {}<left>
inoremap " ""<left>
inoremap ' ''<left>

"===== その他 =====
set history=300
set clipboard+=unnamed
set nobackup
set noswapfile
set autoread

"===== プラグイン設定 =====
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

