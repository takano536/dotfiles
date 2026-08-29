set -gx XDG_CACHE_HOME "$HOME/.cache"
set -gx XDG_CONFIG_HOME "$HOME/.config"
set -gx XDG_DATA_HOME "$HOME/.local/share"
set -gx XDG_STATE_HOME "$HOME/.local/state"

set -gx LESSHISTFILE "$XDG_CACHE_HOME/less/history"
set -gx STARSHIP_CONFIG "$XDG_CONFIG_HOME/starship/prompt.toml"