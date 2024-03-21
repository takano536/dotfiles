# exa is a modern replacement for ls
if type 'eza' > /dev/null 2>&1; then
    alias ls='eza --icons'
fi
alias ll='ls -alF'
alias la='ls -a'
alias l='ls -l1F'

# nvim
alias vi='nvim'
alias vim='nvim'
