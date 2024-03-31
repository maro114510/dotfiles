
if status is-interactive
    # Commands to run in interactive sessions can go here
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

alias vim='nvim'
alias cl="clear"


bind --preset \cp up-or-search


starship init fish | source
