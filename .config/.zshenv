. "$HOME/.cargo/env"

# lang
export LANGUAGE="en_US.UTF-8"
export LANG="${LANGUAGE}"
export LC_ALL="${LANGUAGE}"
export LC_CTYPE="${LANGUAGE}"

# history
# history files
export HISTFILE=${HOME}/.config/zsh/.zsh_history
# size of zsh_history
export HISTSIZE=100000
# size of hisotry files
export SAVEHIST=100000
export HISTFILESIZE=100000
# ignore duplicated zsh_history
setopt hist_ignore_dups
# set start and end
setopt EXTENDED_HISTORY
# delete duplicated zsh_history
setopt hist_ignore_all_dups
# ignore space
setopt hist_reduce_blanks
# ignore old same command
setopt hist_save_no_dups

# other
# not to use beep
setopt no_beep
