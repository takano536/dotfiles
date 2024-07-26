#Requires -Version 5.1

<#
.SYNOPSIS
    Build a environment for Windows.
.DESCRIPTION
    This script installs Scoop and some apps.
    It also copies dotfiles and creates symbolic links.
    This script is intended to be run on a new Windows environment.
    This script requires administrator privilege.
    This script is based on the following script.
.LINK
    https://github.com/takano536/dotfiles
#>

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

# write xdg-envs
$xdgEnvs = @{
    'XDG_CONFIG_HOME' = "$env:USERPROFILE\.config"
    'XDG_CACHE_HOME'  = "$env:USERPROFILE\.cache"
    'XDG_DATA_HOME'   = "$env:USERPROFILE\.local\share"
    'XDG_STATE_HOME'  = "$env:USERPROFILE\.local\state"
}
$xdgEnvs.GetEnumerator() | ForEach-Object { [Environment]::SetEnvironmentVariable($_.Key, $_.Value, 'User') }

# install scoop
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force
Set-Location $env:TEMP
Invoke-WebRequest -UseBasicParsing get.scoop.sh -Outfile installScoop.ps1
./installScoop.ps1 -ScoopDir $env:LOCALAPPDATA\Scoop

# copy dotfiles & load profile
Set-Location $env:USERPROFILE
scoop install git
if (Test-Path "$env:USERPROFILE\.config") { Remove-Item "$env:USERPROFILE\.config" -Recurse -Force }
git clone https://github.com/takano536/dotfiles.git .config
Install-PackageProvider NuGet -Force -ForceBootstrap -Scope CurrentUser
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
    'auto-dark-mode-np',
    'dotnet6-sdk', # for open-tablet-driver
    'dotnet3-sdk', # for mica-for-everyone
    'vcredist'
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
    
    'winfsp-np'
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

# create startup shortcut
$shortcuts = @{
    'Discord.lnk'       = '--start-minimized'
    'WingetUI.lnk'      = '--deamon'
    'SmartTaskbar.lnk'  = ''
    'Thunderbird.lnk'   = ''
    'Rainmeter.lnk'     = ''
    'TranslucentTB.lnk' = ''
}
$startupDir = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$shortcuts.GetEnumerator() | ForEach-Object {
    $wshShell = New-Object -ComObject WScript.Shell
    $sh = New-Object -ComObject WScript.Shell
    $target = $sh.CreateShortcut("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Scoop Apps\$($_.Key)").TargetPath
    $workingDir = Get-Item $target | Select-Object -ExpandProperty DirectoryName
    $shortcut = $wshShell.CreateShortcut("$startupDir\$($_.Key)")
    $shortcut.TargetPath = $target
    $shortcut.Arguments = [string]$_.Value
    $shortcut.WorkingDirectory = $workingDir
    $shortcut.Save()
}

# link dotfiles firefox
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

# disable LocalizedResourceName
$dirs = @(
    "$env:USERPROFILE\Contacts",
    "$env:USERPROFILE\Desktop",
    "$env:USERPROFILE\Documents",
    "$env:USERPROFILE\Downloads",
    "$env:USERPROFILE\Favorites",
    "$env:USERPROFILE\Links",
    "$env:USERPROFILE\Music",
    "$env:USERPROFILE\Pictures",
    "$env:USERPROFILE\Saved Games",
    "$env:USERPROFILE\Searches",
    "$env:USERPROFILE\Videos",
    "$env:APPDATA\Microsoft\Windows\AccountPictures",
    "$env:APPDATA\Microsoft\Windows\Start Menu",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Accessibility",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Administrative Tools",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\System Tools",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
    "$env:PUBLIC",
    "$env:PUBLIC\AccountPictures",
    "$env:PUBLIC\Documents",
    "$env:PUBLIC\Downloads",
    "$env:PUBLIC\Libraries",
    "$env:PUBLIC\Music",
    "$env:PUBLIC\Pictures",
    "$env:PUBLIC\Videos"
)
$dirs | ForEach-Object { 
    Copy-Item "$_\desktop.ini" "$_\desktop.ini.bak" -Force
    (Get-Content $_\desktop.ini) | ForEach-Object {
        $_ -replace 'LocalizedResourceName=', ';LocalizedResourceName='
    } | Set-Content $_\desktop.ini
}

$adminDirs = @(
    "$env:PUBLIC\Desktop"
    "$env:SystemDrive\Users"
)
$adminDirs | ForEach-Object { 
    Write-Output "$_ is skipped"
}

### post-process

Write-Verbose "$psName End"
