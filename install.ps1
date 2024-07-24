#Requires -Version 5.1

param()

$ErrorActionPreference = 'Stop'
$WarningPreference = 'Continue'
$VerbosePreference = 'Continue'
$DebugPreference = 'Continue'

######################################################################
### main-function
######################################################################

### pre-process

$psName = Split-Path $MyInvocation.InvocationName -Leaf
Write-Verbose "$psName Start"

### main-process

# install scoop
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Set-Location $env:TEMP
Invoke-WebRequest -UseBasicParsing get.scoop.sh -Outfile installScoop.ps1
./installScoop.ps1 -ScoopDir $env:LOCALAPPDATA\Scoop

# copy dotfiles & load profile
Set-Location $env:USERPROFILE
scoop install git
if (Test-Path "$env:USERPROFILE\.config") { Remove-Item "$env:USERPROFILE\.config" -Recurse -Force }
git clone https://github.com/takano536/dotfiles.git .config
& "$env:USERPROFILE\.config\powershell\user_profile.ps1"

# add buckets
scoop bucket add extras
scoop bucket add nonportable
scoop bucket add nerd-fonts
scoop bucket add versions
scoop bucket add games

# install apps
scoop install scoop-search
scoop install wingetui
scoop install gsudo

sudo scoop install CascadiaCode-NF --global
sudo scoop install vcredist dotnet3-sdk auto-dark-mode-np

scoop install smarttaskbar
scoop install micaforeveryone
scoop install translucenttb
scoop install windynamicdesktop
scoop install rainmeter

scoop install firefox
scoop install firefoxpwa
scoop install thunderbird
scoop install youtube-music
scoop install discord

scoop install xnconvert
scoop install losslesscut
scoop install gimp

scoop install imagemagick
scoop install starship

scoop install sublime-text
scoop install vscode
scoop install neovim

scoop install opentabletdriver
scoop install osulazer

# hide scoop start menu
$shortcutDir = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Scoop Apps"
if (Test-Path $shortcutDir) { attrib +h $shortcutDir }

# copy shortcuts
$shortcuts = @(
    'Discord.lnk',
    'Firefox.lnk',
    'GIMP.lnk',
    'LosslessCut.lnk',
    'MicaForEveryone.lnk',
    'Rainmeter.lnk',
    'SmartTaskbar.lnk',
    'Sublime Text 4.lnk',
    'Thunderbird.lnk',
    'TranslucentTB.lnk',
    'Visual Studio Code.lnk',
    'WindynamicDesktop.lnk',
    'WingetUI.lnk',
    'XnConvert.lnk',
    'YouTube Music.lnk'
)
$shortcuts | ForEach-Object {
    $shortcut = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Scoop Apps\$_"
    $shortcutDest = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\$_"
    if (Test-Path $shortcut) { Copy-Item $shortcut $shortcutDest -Force }
}

# link dotfiles

# firefox
$firefoxProfile = "$env:SCOOP\persist\firefox\profile"
Set-Location $firefoxProfile
(Get-ChildItem "$env:XDG_CONFIG_HOME\firefox").FullName | ForEach-Object {
    $filename = (Get-Item $_).Name
    if (Test-Path "$firefoxProfile\$filename") { Remove-Item "$firefoxProfile\$filename" -Recurse -Force }
    if ((Get-Item $_).PSIsContainer) { sudo ln -d $_ } else { sudo ln -s $_ }
}

# git-bash
Set-Location $env:USERPROFILE
if (Test-Path "$env:USERPROFILE\.bashrc") { Remove-Item "$env:USERPROFILE\.bashrc" -Force }
sudo ln -s "$env:XDG_CONFIG_HOME\git-bash\.bashrc" "$env:USERPROFILE\.bashrc"
attrib +h "$env:USERPROFILE\.bashrc"

# pwsh
$pwshProfile = "$env:USERPROFILE\Documents\PowerShell"
Set-Location $pwshProfile
if (Test-Path "$pwshProfile\Microsoft.PowerShell_profile.ps1") { Remove-Item "$pwshProfile\Microsoft.PowerShell_profile.ps1" -Force }
sudo ln -s "$env:XDG_CONFIG_HOME\powershell\Microsoft.PowerShell_profile.ps1" "$pwshProfile\Microsoft.PowerShell_profile.ps1"
sudo ln -s "$env:XDG_CONFIG_HOME\powershell\Microsoft.PowerShell_profile.ps1" "$pwshProfile\Microsoft.VSCode_profile.ps1"

# windows-terminal
$wtProfile = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
Set-Location $wtProfile
if (Test-Path "$wtProfile\settings.json") { Remove-Item "$wtProfile\settings.json" -Force }
sudo ln -s "$env:XDG_CONFIG_HOME\windows-terminal\settings.json" "$wtProfile\settings.json"

### post-process

Write-Verbose "$psName End"
