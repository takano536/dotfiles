# detect shell
curr_shell=$(ps -p $$ | tail +2 | awk '{print $NF}') 

# asdf
if [[ -d "$XDG_DATA_HOME/asdf" ]]; then
    . "$ASDF_DIR/asdf.sh"
    if [[ $curr_shell == 'bash' ]]; then
        . "$ASDF_DIR/completions/asdf.bash"
    fi
fi

# rust
if [[ -d "$XDG_DATA_HOME/cargo" ]]; then
    . "$CARGO_HOME/env"
fi

# startship
eval "$(starship init $curr_shell)"
