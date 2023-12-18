
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
set listchars=tab:│·,extends:⟩,precedes:⟨,trail:·,eol:↴,nbsp:%
" show window title
set title
" show statusline
set laststatus=2 
" show cursor
set ruler
" double width character
" "set ambiwidth=double
" syntax highlight
syntax on 
highlight LineNr guifg=#a89984 ctermfg=241

" ===== figure =====
" auto indent
set autoindent
set smartindent
" tabsize
set tabstop=4
set shiftwidth=4
set expandtab
"let g:indent_guides_enable_on_vim_startup = 1

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

" set
set whichwrap+=b,s,h,l,<,>,[,]
set backspace=start,eol,indent


" ===== Apppearance =====
set termguicolors

let g:tokyonight_style = 'night' " available: night, storm
let g:tokyonight_enable_italic = 1

if has('vim_starting')
    let &t_SI .= "\e[6 q"
    let &t_EI .= "\e[2 q"
    let &t_SR .= "\e[4 q"
endif
augroup RestoreCursorShapeOnExit
    autocmd!
    autocmd VimLeave * set guicursor=a:hor1
augroup END

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
    " Unite
    Jetpack 'Shougo/unite.vim'
    " ctrlp
    Jetpack 'ctrlpvim/ctrlp.vim'
    " window size
    Jetpack 'simeji/winresizer'
    Jetpack 'ghifarit53/tokyonight-vim'
    Jetpack 'neoclide/coc.nvim', {'branch': 'release'}
    Jetpack 'hrsh7th/cmp-path'
    Jetpack 'hrsh7th/cmp-cmdline'
    Jetpack 'Shougo/ddc.vim'
    Jetpack 'vim-denops/denops.vim'
    Jetpack 'ervandew/supertab'
    Jetpack 'Shougo/pum.vim'
    Jetpack 'tani/ddc-fuzzy'
    Jetpack 'gelguy/wilder.nvim'
call jetpack#end()

" Unite settings
nnoremap <silent> un :<C-u>Unite buffer<CR>
nnoremap <silent> unf :<C-u>Unite file<CR>
nnoremap <silent> ufr :<C-u>Unite file_rec<CR>
nnoremap <silent> ub :<C-u>Unite bookmark<CR>
nnoremap <silent> umru :<C-u>Unite file_mru<CR>
nnoremap <silent> ur :<C-u>Unite -buffer-name=register register<CR>

au FileType * set fo-=c fo-=r fo-=o

" fzf
" fzf settings
let $FZF_DEFAULT_OPTS="--layout=reverse"
let $FZF_DEFAULT_COMMAND="rg --files --hidden --glob '!.git/**'"
let g:fzf_layout = {'up':'~90%', 'window': { 'width': 0.8, 'height': 0.8,'yoffset':0.5,'xoffset': 0.5, 'border': 'sharp' } }

let mapleader = "\<Space>"
nnoremap <C-f> :Files <CR>
nnoremap <silent> <leader>f :Files<CR>
