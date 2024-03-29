export XDG_CONFIG_HOME="$HOME/.config"

# run runcoms
emulate sh -c 'source /etc/profile'
source "$XDG_CONFIG_HOME/sh/env.rc.sh"
source "$XDG_CONFIG_HOME/zsh/base.rc.zsh"
source "$XDG_CONFIG_HOME/sh/appinit.rc.sh"
source "$XDG_CONFIG_HOME/sh/keybind.rc.sh"
source "$XDG_CONFIG_HOME/sh/alias.rc.sh"

# start fish
# if type 'fish' > /dev/null 2>&1; then
#     exec fish
# fi
