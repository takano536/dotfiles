$DOTFILES_DIR = "$env:USERPROFILE\.config"

$TERMINAL_DIR = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
$POWERSHELL_DIR = "$env:USERPROFILE\Documents\PowerShell"
$SUBLIME_DIR = "$env:LOCALAPPDATA\Scoop\persist\sublime-text\Data\Packages\User"
$FIREFOX_DIR = "$env:LOCALAPPDATA\Scoop\persist\firefox\Profile"

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

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (!$isAdmin) {
    Write-Output 'Error: Please run this script as an administrator'
    exit 1
}

if (Test-Path $DOTFILES_DIR) {
    Write-Output 'Error: The dotfiles directory already exists'
    exit 1
}

git clone 'https://github.com/takano536/dotfiles.git' $DOTFILES_DIR
New-link -ItemType SymbolicLink -Path "$TERMINAL_DIR\settings.json" -Target "$DOTFILES_DIR\windows\windows_terminal\settings.json"
New-link -ItemType SymbolicLink -Path "$POWERSHELL_DIR\Microsoft.PowerShell_profile.ps1" -Target "$DOTFILES_DIR\windows\powershell\Microsoft.PowerShell_profile.ps1"
New-link -ItemType SymbolicLink -Path "$SUBLIME_DIR\Preferences.sublime-settings" -Target "$DOTFILES_DIR\sublime\Preferences.sublime-settings"
New-link -ItemType SymbolicLink -Path "$FIREFOX_DIR\chrome\userChrome.css" -Target "$DOTFILES_DIR\common\firefox\userChrome.css"
New-link -ItemType Junction -Path "$FIREFOX_DIR\chrome\modules" -Target "$DOTFILES_DIR\common\firefox\modules"
New-link -ItemType SymbolicLink -Path "$FIREFOX_DIR\user.js" -Target "$DOTFILES_DIR\common\firefox\user.js"
