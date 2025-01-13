if [ -d "$HOME/bin" ] ; then
    export PATH="$HOME/bin:$PATH"
fi

if [ -d "$HOME/.local/bin" ] ; then
    export PATH="$HOME/.local/bin:$PATH"
fi

if [ -d "$HOME/.local/lib" ] ; then
    export LD_LIBRARY_PATH="$HOME/.local/lib:$LD_LIBRARY_PATH"
fi

# xdg
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"

# asdf
if [ -d "$XDG_DATA_HOME/asdf" ]; then
    export ASDF_DIR="$XDG_DATA_HOME/asdf"
    export ASDF_DATA_DIR="$XDG_DATA_HOME/asdf"
    export ASDF_CONFIG_FILE="$XDG_CONFIG_HOME/asdf/.asdfrc"
fi

# neovim
if [ -d '/opt/nvim-linux64' ]; then
    export PATH="$PATH:/opt/nvim-linux64/bin"
fi

# less
export LESSHISTFILE="$XDG_CACHE_HOME/less/history"

# starship
export STARSHIP_CONFIG="$XDG_CONFIG_HOME/starship/prompt.toml"

# shell history
current_shell=`basename "$(readlink "/proc/$$/exe")"`
export HISTFILE="$XDG_CACHE_HOME/$current_shell/.${current_shell}_history"
export HISTSIZE=100000
export SAVEHIST=100000
if [ ! -d "$XDG_CACHE_HOME/zsh" ]; then
    mkdir -p "$XDG_CACHE_HOME/zsh"
fi

# python history
export PYTHONSTARTUP="$XDG_CONFIG_HOME/python/.pythonrc"
