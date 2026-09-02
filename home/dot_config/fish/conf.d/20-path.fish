fish_add_path --global "$HOME/.local/bin"
fish_add_path --global "$HOME/bin"
fish_add_path --global "$HOME/.bun/bin"

if test -x "$HOME/.local/share/fnm/fnm"
    fish_add_path "$HOME/.local/share/fnm"
    fnm env --use-on-cd --shell fish | source
end
