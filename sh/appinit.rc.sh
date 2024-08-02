# detect shell
current_shell=$(ps -p $$ | tail +2 | awk '{print $NF}') 

# asdf
if [ -d "$XDG_DATA_HOME/asdf" ]; then
    source "$ASDF_DIR/asdf.sh"
    if [ $current_shell = 'bash' ]; then
        source "$ASDF_DIR/completions/asdf.bash"
    fi
fi

# startship
if type 'starship' > /dev/null 2>&1; then
    eval "$(starship init $current_shell)"
fi
