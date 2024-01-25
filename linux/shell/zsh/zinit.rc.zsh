repo='zsh-users/zsh-autosuggestions'
zinit ice wait; zinit light $repo
source "$XDG_DATA_HOME/zinit/plugins/${repo//\//---}/zsh-autosuggestions.zsh"
zinit ice wait; zinit light marlonrichert/zsh-autocomplete
zinit ice wait; zinit load agkozak/zsh-z
zinit ice wait'!0'; zinit light zsh-users/zsh-syntax-highlighting
