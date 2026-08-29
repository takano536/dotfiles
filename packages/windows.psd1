<#
    Packages that install.ps1 bootstraps on Windows.

    Read with Import-PowerShellDataFile, so this file must stay a plain data
    hashtable (no expressions, no commands).

    Scoop is the only package manager: this repository pins Scoop's install
    layout (Windows Terminal starts %LOCALAPPDATA%\Programs\Scoop\apps\pwsh and
    ...\apps\git), so there is no second source for these packages.

    Not bootstrapped on purpose: AI coding agents (Oh My Pi / omp, Claude Code,
    Codex CLI), Docker, WSL distributions, GUI applications and IDEs (Firefox,
    Sublime Text, Zed, Windows Terminal), fonts, credentials and SSH keys, and
    language runtimes (Bun, Node.js, Python) that no Windows dotfile needs.
#>

@{
    # Scoop buckets required by the packages below. 'main' ships with Scoop;
    # 'extras' is only needed for lazygit.
    Buckets = @(
        'main'
        'extras'
    )

    # Without these the applied dotfiles are broken or fall back to defaults.
    Required  = @(
        @{
            Scoop   = 'git'
            Command = 'git'
            Why     = 'Windows Terminal Git Bash profile, .bashrc, chezmoi source updates'
        }
        @{
            Scoop   = 'pwsh'
            Command = 'pwsh'
            Why     = 'Windows Terminal default profile, Documents/PowerShell profile'
        }
        @{
            Scoop   = 'neovim'
            Command = 'nvim'
            Why     = 'vi/vim aliases in PowerShell and bash, .config/nvim'
        }
        @{
            Scoop   = 'starship'
            Command = 'starship'
            Why     = 'prompt.ps1 and bash tools.bash, .config/starship'
        }
        @{
            Scoop   = 'chezmoi'
            Command = 'chezmoi'
            Why     = 'applies this repository'
        }
    )

    # Everyday CLI and TUI tools. A failure here is a warning, not an error.
    Optional  = @(
        @{
            Scoop   = 'zoxide'
            Command = 'zoxide'
            Why     = 'initialised by .config/bash/tools.bash'
        }
        @{
            Scoop   = 'eza'
            Command = 'eza'
            Why     = 'ls aliases in .config/bash/aliases.bash'
        }
        @{
            Scoop   = 'tree-sitter'
            Command = 'tree-sitter'
            Why     = 'parser installs in .config/nvim/after/plugin/treesitter.rc.lua'
        }
        @{
            Scoop   = 'gcc'
            Command = 'gcc'
            Why     = 'treesitter.rc.lua sets CC=gcc to build parsers on Windows'
        }
        @{
            Scoop   = 'ripgrep'
            Command = 'rg'
            Why     = 'everyday search from the shell'
        }
        @{
            Scoop   = 'fd'
            Command = 'fd'
            Why     = 'everyday file search from the shell'
        }
        @{
            Scoop   = 'fzf'
            Command = 'fzf'
            Why     = 'interactive filtering from the shell'
        }
        @{
            Scoop   = 'bat'
            Command = 'bat'
            Why     = 'everyday file viewer'
        }
        @{
            Scoop   = 'jq'
            Command = 'jq'
            Why     = 'everyday JSON inspection'
        }
        @{
            Scoop   = 'delta'
            Command = 'delta'
            Why     = 'readable git diffs'
        }
        @{
            Scoop   = 'lazygit'
            Command = 'lazygit'
            Why     = 'git TUI'
        }
        @{
            Scoop   = 'gh'
            Command = 'gh'
            Why     = 'GitHub CLI for this repository and pull requests'
        }
        @{
            Scoop   = 'btop'
            Command = 'btop'
            Why     = 'process TUI'
        }
        @{
            Scoop   = 'yazi'
            Command = 'yazi'
            Why     = 'file manager TUI'
        }
        @{
            Scoop   = 'fastfetch'
            Command = 'fastfetch'
            Why     = 'system summary'
        }
    )

    # Imported by Documents/PowerShell/Profile/modules.ps1 in PowerShell 7, so
    # they are installed with pwsh, not with Windows PowerShell.
    PSModules = @(
        'Terminal-Icons'
        'CompletionPredictor'
        'PowerType'
    )
}
