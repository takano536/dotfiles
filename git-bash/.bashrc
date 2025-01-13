export XDG_CONFIG_HOME="$HOME/.config"

# run runcoms
source ~/.config/sh/env.rc.sh
source ~/.config/bash/base.rc.bash
source ~/.config/sh/keybind.rc.sh
source ~/.config/sh/alias.rc.sh
source ~/.config/sh/appinit.rc.sh

# starship
export STARSHIP_CONFIG=~/.config/starship/prompt.toml
if type 'starship' > /dev/null 2>&1 ; then
    eval "$(starship init bash)"
fi
