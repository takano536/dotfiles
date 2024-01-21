# set config home if not set
if [ -z "$XDG_CONFIG_HOME" ]; then
    export XDG_CONFIG_HOME="$HOME/.config"
fi

# run runcoms
. "$XDG_CONFIG_HOME/shell/common/env.rc.sh"
. "$XDG_CONFIG_HOME/shell/bash/base.rc.bash"
. "$XDG_CONFIG_HOME/shell/common/keybind.rc.sh"
. "$XDG_CONFIG_HOME/shell/common/alias.rc.sh"
. "$XDG_CONFIG_HOME/shell/common/appinit.rc.sh"
