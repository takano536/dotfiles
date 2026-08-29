##### History #####
HISTCONTROL=ignoreboth:erasedups
HISTSIZE=100000
HISTFILESIZE=200000
HISTFILE="$XDG_STATE_HOME/bash/history"

mkdir -p "${HISTFILE%/*}"

shopt -s histappend
shopt -s cmdhist
shopt -s lithist

##### Shell Options #####
shopt -s checkwinsize
shopt -s globstar

##### Completion #####
if [[ -r /usr/share/bash-completion/bash_completion ]]; then
    source /usr/share/bash-completion/bash_completion
elif [[ -r /etc/bash_completion ]]; then
    source /etc/bash_completion
fi