export STARSHIP_CONFIG="$XDG_CONFIG_HOME/starship/prompt.toml"
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init bash)"
fi

if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init bash)"
fi
