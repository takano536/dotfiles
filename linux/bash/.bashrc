export XDG_CONFIG_HOME="$HOME/.config/linux"

# run runcoms
source "$XDG_CONFIG_HOME/sh/env.rc.sh"
source "$XDG_CONFIG_HOME/bash/base.rc.bash"
source "$XDG_CONFIG_HOME/sh/appinit.rc.sh"
source "$XDG_CONFIG_HOME/sh/keybind.rc.sh"
source "$XDG_CONFIG_HOME/sh/alias.rc.sh"

# start fish
# if type 'fish' > /dev/null 2>&1; then
#     exec fish
# fi
