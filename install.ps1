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
$bucekts = @(
    'extras',
    'nonportable',
    'nerd-fonts',
    'versions',
    'games'
)
$bucekts | ForEach-Object { scoop bucket add $_ }

# install global apps
$globalApps = @(
    'CascadeaCode-NF'
)
$globalApps | ForEach-Object { sudo scoop install $_ --global }

# install admin privilege apps
$adminApps = @(
    'vcredist',
    'dotnet3-sdk',
    'auto-dark-mode-np'
)
Invoke-Expression "sudo scoop install $adminApps"

# install normal apps
$apps = @(
    'scoop-search',
    'wingetui',
    'gsudo',
    'pwsh',
    
    'smarttaskbar',
    'micaforeveryone',
    'translucenttb',
    'windynamicdesktop',
    'rainmeter',
    
    'firefox',
    'firefoxpwa',
    'thunderbird',
    'youtube-music',
    'discord',
    
    'xnconvert',
    'losslesscut',
    'gimp',
    
    'imagemagick',
    'starship',
    
    'sublime-text',
    'vscode',
    'neovim',

    'opentabletdriver',
    'osulazer'
)
$apps | ForEach-Object { try { sudo scoop install $_ } catch { Write-Warning "Failed to install $_" } }

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
    if ((Get-Item $_).PSIsContainer) { sudo cmd /c "mklink /d $filename $_" } else { sudo New-Item -ItemType SymbolicLink -Value $_ -Path $filename }
}

# git-bash
Set-Location $env:USERPROFILE
if (Test-Path "$env:USERPROFILE\.bashrc") { Remove-Item "$env:USERPROFILE\.bashrc" -Force }
sudo New-Item -ItemType SymbolicLink -Value "$env:XDG_CONFIG_HOME\git-bash\.bashrc" -Path "$env:USERPROFILE\.bashrc"
attrib +h "$env:USERPROFILE\.bashrc"

# pwsh
$pwshProfile = "$env:USERPROFILE\Documents\PowerShell"
New-Item $pwshProfile -ItemType Directory -ErrorAction SilentlyContinue
Set-Location $pwshProfile
if (Test-Path "$pwshProfile\Microsoft.PowerShell_profile.ps1") { Remove-Item "$pwshProfile\Microsoft.PowerShell_profile.ps1" -Force }
sudo New-Item -ItemType SymbolicLink -Value "$env:XDG_CONFIG_HOME\powershell\Microsoft.PowerShell_profile.ps1" -Path "$pwshProfile\Microsoft.PowerShell_profile.ps1"
sudo New-Item -ItemType SymbolicLink -Value "$env:XDG_CONFIG_HOME\powershell\Microsoft.PowerShell_profile.ps1" -Path "$pwshProfile\Microsoft.VSCode_profile.ps1"

# windows-terminal
$wtProfile = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
New-Item $wtProfile -ItemType Directory -ErrorAction SilentlyContinue
Set-Location $wtProfile
if (Test-Path "$wtProfile\settings.json") { Remove-Item "$wtProfile\settings.json" -Force }
sudo New-Item -ItemType SymbolicLink -Value "$env:XDG_CONFIG_HOME\windows-terminal\settings.json"-Path "$wtProfile\settings.json" -Force

### post-process

Write-Verbose "$psName End"
