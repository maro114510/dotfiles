
if status is-interactive
    # Commands to run in interactive sessions can go here
    eval (/opt/homebrew/bin/brew shellenv)
end

function fish_user_key_bindings
    for mode in default insert visual
        fish_default_key_bindings -M $mode
    end
    fish_vi_key_bindings --no-erase
    if test "$__fish_active_key_bindings" = fish_vi_key_bindings
        bind -M insert -m default jj force-repaint
    end
end

set -Ux EDITOR /usr/bin/nvim

# export commands
export PATH="$HOME/commands:$PATH"

##### alias #####
alias ls='lsd'
alias ll='ls -l'
alias la='ls -al'
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'
alias gp="git pull"
alias gf='git flow'
alias vim='nvim'
alias v='nvim'
alias vi='vi'
alias lg='lazygit'
alias cl='clear'

alias ac='sh ~/commands/auto_commit.sh'
alias めも='sh ~/commands/create_memo.sh'
set SESSION_NAME (date +'%H%M%S_%m/%d')
alias tmuxer='tmux new -s $SESSION_NAME \; source-file ~/.tmux.session.conf'
alias tmuxx='tmux new -s $SESSION_NAME'



bind --preset \cp up-or-search

## function

export FZF_DEFAULT_COMMAND='rg --files --hidden --follow --glob "!.git/*"'
export FZF_DEFAULT_OPTS="--height 50% --layout=reverse --border --inline-info --preview 'head -100 {}'"
# ref: https://momozo.tech/2021/03/10/fzf%E3%81%A7zsh%E3%82%BF%E3%83%BC%E3%83%9F%E3%83%8A%E3%83%AB%E4%BD%9C%E6%A5%AD%E3%82%92%E5%8A%B9%E7%8E%87%E5%8C%96/
function vf
    set file (fzf --preview 'bat --style=numbers --color=always {}' --query="$argv") 
    if test -n "$file"
        nvim $file
    else
        return 1
    end
end

function fgh
	set selected $(ghq list | fzf)

	if test -n "$selected"
		cd $(ghq root)/$selected
	end
end

function frm
    ls -al | fzf -m | xargs -I {} rm {}
end




starship init fish | source

