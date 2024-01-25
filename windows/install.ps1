$DOTFILES_DIR = "$env:USERPROFILE\.config"

$TERMINAL_DIR = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
$POWERSHELL_DIR = "$env:USERPROFILE\Documents\PowerShell"
$SUBLIME_DIR = "$env:LOCALAPPDATA\Scoop\persist\sublime-text\Data\Packages\User"
$FIREFOX_DIR = "$env:LOCALAPPDATA\Scoop\persist\firefox\Profile\chrome"

function New-link {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ItemType,
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Target
    )
    New-Item -ItemType $ItemType -Path $Path.tmp -Target $Target
    if (Test-Path $Path) {
        Rename-Item -Path $Path -NewName "$Path.bak"
        Reneme-Item -Path $Path.tmp -NewName $Path
    }
}

git clone 'https://github.com/takano536/dotfiles.git' $DOTFILES_DIR
New-link -ItemType SymbolicLink -Path "$TERMINAL_DIR\settings.json" -Target "$DOTFILES_DIR\windows\windows_terminal\settings.json"
New-link -ItemType SymbolicLink -Path "$POWERSHELL_DIR\Microsoft.PowerShell_profile.ps1" -Target "$DOTFILES_DIR\windows\powershell\Microsoft.PowerShell_profile.ps1"
New-link -ItemType SymbolicLink -Path "$SUBLIME_DIR\Preferences.sublime-settings" -Target "$DOTFILES_DIR\sublime\Preferences.sublime-settings"
New-link -ItemType SymbolicLink -Path "$FIREFOX_DIR\userChrome.css" -Target "$DOTFILES_DIR\common\firefox\userChrome.css"
New-link -ItemType Junction -Path "$FIREFOX_DIR\modules" -Target "$DOTFILES_DIR\common\firefox\modules"
