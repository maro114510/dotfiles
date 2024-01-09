# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
# ZSH_THEME="robbyrussell"
# ZSH_THEME="agnoster"
# ZSH_THEME="jonathan"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
	git
	zsh-syntax-highlighting
	zsh-completions
	zsh-autosuggestions
	zsh-history-substring-search
	z
)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

### locale ###
export LANG="en_US.UTF-8"

### homebrew ###
if uname -a | grep -sq "Linux"; then
	export PATH=$HOME/lazygit:$PATH
	export PATH=/snap/bin:$PATH
	export PATH=$HOME/node-v21.5.0-linux-armv7l/bin:$PATH
	echo "ok"
elif [ "$(uname)" = "Darwin" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

### Node.js ###
export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

### pyenv ###
export PATH="$HOME/.pyenv/versions/3.11.3/bin:$PATH"

### pyenv-virtualenv ###
if which pyenv-virtualenv-init > /dev/null; then eval "$(pyenv virtualenv-init -)"; fi

### rye ###
source "$HOME/.rye/env"


### Golang ###
if uname -a | grep -sq "Linux"; then
	export PATH=$PATH:/usr/local/go/bin
elif [ "$(uname)" = "Darwin" ]; then
	export GOPATH=$HOME/go
	export GOBIN=$GOPATH/bin
	export PATH=$PATH:$GOBIN
	export PATH=$PATH:$(go env GOPATH)/bin
fi

export GOPATH=$HOME/go
export GOBIN=$GOPATH/bin
export PATH=$PATH:$GOBIN
export PATH=$PATH:$(go env GOPATH)/bin

### Rust ###
export PATH="$HOME/.cargo/bin:$PATH"

### peco ###
function peco-select-history() {
	local tac
	if which tac > /dev/null; then
		tac="tac"
	else
		tac="tail -r"
	fi
	BUFFER=$(\history -n 1 | \
	eval $tac | \
		peco --query "$LBUFFER")
	CURSOR=$#BUFFER
	zle clear-screen
}
zle -N peco-select-history
bindkey '^r' peco-select-history

# export commands
export PATH="$HOME/commands:$PATH"


### Starship ###
eval "$(starship init zsh)"


##### alias #####
alias ls='lsd'
alias ll='ls -l'
alias la='ls -al'
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'
alias prp='poetry run python'
alias gp="git pull"
alias gf='git flow'
alias v='nvim'
alias vim='nvim'
alias vi='vi'
alias lg='lazygit'
alias cl='clear'

alias ac='sh ~/commands/auto_commit.sh'
alias memo='sh ~/commands/create_memo.sh'
alias めも='sh ~/commands/create_memo.sh'
alias tmuxer='tmux new -s \; source-file ~/.tmux.session.conf'

if [ -f "$HOME/.env" ]; then
	source "$HOME/.env"

	if [ "$LOCAL_NAME" = "macbook" ]; then
		bfile="$HOME/ghq/github.com/maro114510/dotfiles/mac_book/Brewfile"
		alias brewd="brew bundle dump --force --file=$bfifle"
	elif [ "$LOCAL_NAME" = "macmini" ]; then
		bfile="$HOME/ghq/github.com/maro114510/dotfiles/mac_mini/Brewfile"
		alias brewd="brew bundle dump --force --file=$bfile"
	fi
fi


##### fzf #####

export FZF_DEFAULT_COMMAND='rg --files --hidden --follow --glob "!.git/*"'
export FZF_DEFAULT_OPTS="--height 50% --layout=reverse --border --inline-info --preview 'head -100 {}'"
# using ripgrep combined with preview
# find-in-file - usage: fif <searchTerm>
fif() {
	if [ ! "$#" -gt 0 ]; then echo "Need a string to search for!"; return 1; fi
	rg --files-with-matches --no-messages "$1" | fzf --preview "highlight -O ansi -l {} 2> /dev/null | rg --colors 'match:bg:yellow' --ignore-case --pretty --context 10 '$1' || rg --ignore-case --pretty --context 10 '$1' {}"
}
# fd - cd to selected directory
# https://qiita.com/kamykn/items/aa9920f07487559c0c7e
fcd() {
local dir
	dir=$(find ${1:-.} -path '*/\.*' -prune \
		-o -type d -print 2> /dev/null | fzf +m) &&
	cd "$dir"
}
# docker container rm
# ref: https://momozo.tech/2021/03/10/fzf%E3%81%A7zsh%E3%82%BF%E3%83%BC%E3%83%9F%E3%83%8A%E3%83%AB%E4%BD%9C%E6%A5%AD%E3%82%92%E5%8A%B9%E7%8E%87%E5%8C%96/
fdcntrm() {
	local cid
	cid=$(docker ps -a | sed 1d | fzf -m -q "$1" | awk '{print $1}')
	[ -n "$cid" ] && echo $cid | xargs docker container rm -f
}
# docker image rm
fdimgrm() {
	local cid
	cid=$(docker image ls -a | sed 1d | fzf -m -q "$1" | awk '{print $1}')
	[ -n "$cid" ] && echo $cid | xargs docker image rm -f
}
# vim with fzf
vf() {
	local file
	file=$(fzf --preview 'bat --style=numbers --color=always {}' --query="$1") &&
	nvim "${file}" || return 1
}
# fh - repeat history
fh() {
	eval $( ([ -n "$ZSH_NAME" ] && fc -l 1 || history) | fzf +s --tac | sed 's/ *[0-9]* *//')
}
# fdg - ghq
fgh() {
	local selected
	selected=$(ghq list | fzf)

	if [ "x$selected" != "x" ]; then
		cd $(ghq root)/$selected
	fi
}


# bun completions
[ -s "/Users/atsuki/.bun/_bun" ] && source "/Users/atsuki/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# Fig
