# eza
if type 'eza' > /dev/null 2>&1 ; then
    alias ls='eza --icons'
fi
alias ll='ls -alF'
alias la='ls -a'
alias l='ls -l1F'

# nvim
if type 'nvim' > /dev/null 2>&1; then
    alias vi='nvim'
    alias vim='nvim'
fi
