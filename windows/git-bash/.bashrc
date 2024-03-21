export XDG_CONFIG_HOME="$HOME/.config/linux"

# run runcoms
. "$XDG_CONFIG_HOME/shell/sh/env.rc.sh"
. "$XDG_CONFIG_HOME/shell/bash/base.rc.bash"
. "$XDG_CONFIG_HOME/shell/sh/keybind.rc.sh"
. "$XDG_CONFIG_HOME/shell/sh/alias.rc.sh"
. "$XDG_CONFIG_HOME/shell/sh/appinit.rc.sh"

# starship
export STARSHIP_CONFIG="$HOME/.config/windows/starship/prompt.toml"
eval "$(starship init bash)"
