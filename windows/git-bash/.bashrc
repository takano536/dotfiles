export XDG_CONFIG_HOME="$HOME/.config/linux"

# run runcoms
. "$XDG_CONFIG_HOME/shell/common/env.rc.sh"
. "$XDG_CONFIG_HOME/shell/bash/base.rc.bash"
. "$XDG_CONFIG_HOME/shell/common/keybind.rc.sh"
. "$XDG_CONFIG_HOME/shell/common/alias.rc.sh"
. "$XDG_CONFIG_HOME/shell/common/appinit.rc.sh"

# starship
export STARSHIP_CONFIG="$HOME/.config/windows/starship/prompt.toml"
eval "$(starship init bash)"
