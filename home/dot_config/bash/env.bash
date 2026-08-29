##### Environment #####
export USER="${USER:-$(id -un)}"

export XDG_CACHE_HOME="$HOME/.cache"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"

export LESSHISTFILE="$XDG_CACHE_HOME/less/history"
export INPUTRC="$XDG_CONFIG_HOME/bash/inputrc"

##### PATH #####
# Mirrors fish conf.d/20-path.fish. install.sh puts chezmoi into ~/.local/bin
# when Debian has no package for it, so bash has to look there too.
for bin_dir in "$HOME/.local/bin" "$HOME/bin" "$HOME/.bun/bin"; do
    case ":$PATH:" in
        *":$bin_dir:"*) ;;
        *) [[ -d $bin_dir ]] && PATH="$bin_dir:$PATH" ;;
    esac
done
unset bin_dir
export PATH