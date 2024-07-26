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
.PARAMETER ScoopDir
    Specifies Scoop root path.
    If not specified, Scoop will be installed to '$env:LOCALAPPDATA\scoop'.
.PARAMETER NugetMinVersion
    Specifies the minimum version of NuGet.
    If not specified, version 2.8.5.201 will be installed.
.PARAMETER NoSetEnvs
    Specifies whether to set environment variables.
    If specified, environment variables will not be set.
.PARAMETER Debug
    Specifies whether to output debug information.
    If specified, debug information will be output.
.LINK
    https://github.com/takano536/dotfiles
#>

param(
    [string]$ScoopDir = "$env:LOCALAPPDATA\Scoop",
    [string]$NugetMinVersion = '2.8.5.201',
    [switch]$NoSetEnvs,
    [switch]$Debug
)

$ErrorActionPreference = 'Stop'
$WarningPreference = 'Continue'
$VerbosePreference = 'Continue'
if ($Debug) { $DebugPreference = 'Continue' } else { $DebugPreference = 'SilentlyContinue' }

######################################################################
### functions
######################################################################

function Set-EnvironmentVariable {
    param(
        [string]$Name,
        [string]$Value,
        [string]$Scope = 'User'
    )

    if (Test-Path variables:\$Name) { return }
    [Environment]::SetEnvironmentVariable($Name, $Value, $Scope)
    Write-Verbose "Set $Name to $Value for $Scope."
}

function Install-Scoop {
    param(
        [string]$Dir
    )

    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force
    if (!(Test-Path $env:TEMP)) { New-Item -Path $env:TEMP -ItemType Directory }
    Set-Location $env:TEMP
    Invoke-WebRequest -UseBasicParsing get.scoop.sh -Outfile installScoop.ps1
    ./installScoop.ps1 -Dir $Dir
    Write-Verbose 'Scoop has been installed.'
}

function New-Startup {
    param(
        [string]$TargetName,
        [string]$Arguments
    )

    $wshShell = New-Object -ComObject WScript.Shell
    $target = $wshShell.CreateShortcut("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Scoop Apps\$TargetName").TargetPath
    $workingDir = Get-Item $target | Select-Object -ExpandProperty DirectoryName
    $shortcut = $wshShell.CreateShortcut("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\$TargetName")
    $shortcut.TargetPath = $target
    $shortcut.Arguments = $Arguments
    $shortcut.WorkingDirectory = $workingDir
    $shortcut.Save()
    Write-Verbose "Created a startup shortcut for $TargetName."
}

function New-Symlink {
    param(
        [string]$Target,
        [string]$Link
    )

    if (Test-Path $Link) { Remove-Item $Link -Force }
    if ((Get-Item $Target).PSIsContainer) { 
        cmd /c "mklink /d $Link $Target"
    }
    else {
        New-Item -ItemType SymbolicLink -Value $Target -Path $Link -Force
    }
}

######################################################################
### main-function
######################################################################

### pre-process

$psName = Split-Path $MyInvocation.InvocationName -Leaf
Write-Verbose "$psName Start"

### main-process

# Set Environment Variables
$writeEnvs = @{
    'XDG_CONFIG_HOME' = "$env:USERPROFILE\.config"
    'XDG_CACHE_HOME'  = "$env:USERPROFILE\.cache"
    'XDG_DATA_HOME'   = "$env:USERPROFILE\.local\share"
    'XDG_STATE_HOME'  = "$env:USERPROFILE\.local\state"
    'SCOOP'           = $ScoopDir
    'SCOOP_HOME'      = $ScoopDir
    'SCOOP_ROOT'      = $ScoopDir
}
if (!$NoSetEnvs) {
    $writeEnvs.GetEnumerator() | ForEach-Object { 
        Set-EnvironmentVariable -Name $_.Key -Value $_.Value
    }
}

# install scoop
try { if (!(Test-Path $ScoopDir)) { Install-Scoop -Dir $ScoopDir } }
catch { throw 'Failed to install Scoop' }

# install mandatory apps
$mandatoryApps = @(
    'git',
    'gsudo'
)
$mandatoryApps | ForEach-Object {
    try { scoop install $_ } catch { throw "Failed to install $_" } 
}

# copy dotfiles & load profile
Set-Location $env:USERPROFILE
if (Test-Path "$env:USERPROFILE\.config") { Remove-Item "$env:USERPROFILE\.config" -Recurse -Force }
Install-PackageProvider -Name NuGet -MinimumVersion $NugetMinVersion -Force
git clone https://github.com/takano536/dotfiles.git .config
try { & "$env:USERPROFILE\.config\powershell\user_profile.ps1" } catch { throw 'Failed to load profile' }

# add buckets
$bucekts = @(
    'extras',
    'nonportable',
    'nerd-fonts',
    'versions',
    'games'
)
$bucekts | ForEach-Object { 
    try { scoop bucket add $_ } catch { Write-Warning "Failed to add $_" }
}

# install global apps
$globalApps = @(
    'CascadeaCode-NF'
)
$globalApps | ForEach-Object { 
    try { sudo scoop install $_ --global } catch { Write-Warning 'Failed to install $_' }
}

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
$apps | ForEach-Object { 
    try { scoop install $_ } catch { Write-Warning "Failed to install $_" }
}

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
$shortcuts.GetEnumerator() | ForEach-Object {
    New-Startup -TargetName $_.Key -Arguments $_.Value
}

# link dotfiles firefox
$firefoxProfile = "$env:SCOOP\persist\firefox\profile"
if (Test-Path $firefoxProfile) {
    (Get-ChildItem "$env:USERPROFILE\.config\firefox").FullName | ForEach-Object {
        $target = (Get-Item $_).FullName
        $link = "$firefoxProfile\$((Get-Item $_).Name)"
        sudo New-Symlink -Target $target -Link $link
    }
}

# git-bash
sudo New-Symlink -Target "$env:USERPROFILE\.config\git-bash\.bashrc" -Link "$env:USERPROFILE\.bashrc"

# pwsh
$pwshProfile = "$env:USERPROFILE\Documents\PowerShell"
New-Item $pwshProfile -ItemType Directory -ErrorAction SilentlyContinue
$target = "$env:USERPROFILE\.config\powershell\Microsoft.PowerShell_profile.ps1"
$profileNames = @(
    'Microsoft.PowerShell_profile.ps1',
    'Microsoft.VSCode_profile.ps1'
)
$profileNames | ForEach-Object {
    sudo New-Symlink -Target $target -Link "$pwshProfile\$_"
}

# windows-terminal
$wtProfile = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
New-Item $wtProfile -ItemType Directory -ErrorAction SilentlyContinue
$target = "$env:USERPROFILE\.config\windows-terminal\settings.json"
$link = "$wtProfile\settings.json"
sudo New-Symlink -Target $target -Link $link

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
