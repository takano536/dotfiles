# keybind list
keybinds=()
keybinds+=('^[[1;5C forward-word')
keybinds+=('^[[1;5D backward-word')

# set keybinds
current_shell=$(ps -p $$ | tail +2 | awk '{print $NF}')
if [ $current_shell = 'zsh' ]; then command='bindkey'; else command='bind'; fi
if [ $current_shell = 'zsh' ]; then delim=' '; else delim=':'; fi
for keybind in "${keybinds[@]}"; do
    key=$(echo "$keybind" | awk '{print $1}')
    bind=$(echo "$keybind" | awk '{print $2}')
    eval "$command \"$key\"$delim$bind"
done
