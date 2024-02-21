if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi

if [ -d "$HOME/.local/lib" ] ; then
    MODULE_PATH="$HOME/.local/lib:$MODULE_PATH"
fi

# xdg
export XDG_CONFIG_HOME="$HOME/.config/linux"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"

# asdf
if [[ -d "$XDG_DATA_HOME/asdf" ]]; then
    export ASDF_DIR="$XDG_DATA_HOME/asdf"
    export ASDF_DATA_DIR="$XDG_DATA_HOME/asdf"
    export ASDF_CONFIG_FILE="$XDG_CONFIG_HOME/asdf/.asdfrc"
fi

# less
export LESSHISTFILE="$XDG_CACHE_HOME/less/history"

# starship
export STARSHIP_CONFIG="$XDG_CONFIG_HOME/starship/prompt.toml"

# shell history
curr_shell=$(ps -p $$ | tail +2 | awk '{print $NF}')
export HISTFILE="$XDG_CACHE_HOME/$curr_shell/.${curr_shell}_history"
export HISTSIZE=1000
export SAVEHIST=100000

# python history
export PYTHONSTARTUP="$XDG_CONFIG_HOME/python/.pythonrc"

# rust
export CARGO_HOME="$XDG_DATA_HOME/cargo"
export RUSTUP_HOME="$XDG_DATA_HOME/rustup"
