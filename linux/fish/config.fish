set fish_greeting ""

# Theme Upstream: https://github.com/folke/tokyonight.nvim/blob/main/extras/fish/tokyonight_storm.fish
set fish_color_normal c0caf5
set fish_color_command 7dcfff
set fish_color_keyword bb9af7
set fish_color_quote e0af68
set fish_color_redirection c0caf5
set fish_color_end ff9e64
set fish_color_error f7768e
set fish_color_param 9d7cd8
set fish_color_comment 565f89
set fish_color_selection --background=2e3c64
set fish_color_search_match --background=2e3c64
set fish_color_operator 9ece6a
set fish_color_escape bb9af7
set fish_color_autosuggestion 565f89
set fish_pager_color_progress 565f89
set fish_pager_color_prefix 7dcfff
set fish_pager_color_completion c0caf5
set fish_pager_color_description 565f89
set fish_pager_color_selected_background --background=2e3c64

# Aliases
if type -q eza
    alias ls 'eza --icons'
end
alias la 'ls -A'
alias ll 'ls -lA'
alias vi 'nvim'
alias vim 'nvim'

# Prompt
starship init fish | source
