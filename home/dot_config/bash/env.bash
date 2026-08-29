##### Environment #####
export USER="${USER:-$(id -un)}"

export XDG_CACHE_HOME="$HOME/.cache"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"

export LESSHISTFILE="$XDG_CACHE_HOME/less/history"
export INPUTRC="$XDG_CONFIG_HOME/bash/inputrc"