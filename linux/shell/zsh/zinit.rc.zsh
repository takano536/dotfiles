# auto suggestions
repo='zsh-users/zsh-autosuggestions'
zinit ice wait; zinit light $repo
source "$XDG_DATA_HOME/zinit/plugins/${repo//\//---}/zsh-autosuggestions.zsh"

# command completion
zinit ice wait; zinit light zsh-users/zsh-completions

# syntax highlighting
zinit ice wait'!0'; zinit light zsh-users/zsh-syntax-highlighting
