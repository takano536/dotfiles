if test -d "$HOME/bin"
    fish_add_path "$HOME/bin"
end

if test -d "$HOME/.local/bin"
    fish_add_path "$HOME/.local/bin"
end

if test -d "$HOME/.local/lib"
    set -gx LD_LIBRARY_PATH "$HOME/.local/lib" $LD_LIBRARY_PATH
end

# xdg
set -gx XDG_CONFIG_HOME "$HOME/.config"
set -gx XDG_CACHE_HOME "$HOME/.cache"
set -gx XDG_DATA_HOME "$HOME/.local/share"
set -gx XDG_STATE_HOME "$HOME/.local/state"

# asdf
if test -d "$XDG_DATA_HOME/asdf"
    set -gx ASDF_DIR "$XDG_DATA_HOME/asdf"
    set -gx ASDF_DATA_DIR "$XDG_DATA_HOME/asdf"
    set -gx ASDF_CONFIG_FILE "$XDG_CONFIG_HOME/asdf/.asdfrc"
end

# rust
set -gx CARGO_HOME "$XDG_DATA_HOME/cargo"
set -gx RUSTUP_HOME "$XDG_DATA_HOME/rustup"
if test -d "$XDG_DATA_HOME/cargo"
    fish_add_path "$XDG_DATA_HOME/cargo/bin"
end

# neovim
if test -d "/opt/nvim-linux64"
    fish_add_path "/opt/nvim-linux64/bin"
end

# less
set -gx LESSHISTFILE "$XDG_CACHE_HOME/less/history"

# starship
set -gx STARSHIP_CONFIG "$XDG_CONFIG_HOME/starship/prompt.toml"

# python history
set -gx PYTHONSTARTUP "$XDG_CONFIG_HOME/python/.pythonrc"
