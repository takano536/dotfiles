##### Env #####
$env:XDG_CACHE_HOME = "$env:USERPROFILE\.cache"
$env:XDG_CONFIG_HOME = "$env:USERPROFILE\.config"
$env:XDG_DATA_HOME = "$env:USERPROFILE\.local\share"
$env:XDG_STATE_HOME = "$env:USERPROFILE\.local\state"

$env:LESSHISTFILE = "$env:XDG_CACHE_HOME\less\.lesshst"
$env:STARSHIP_CONFIG = "$env:XDG_CONFIG_HOME\starship\prompt.toml"

$env:SCOOP = "$env:LOCALAPPDATA\Scoop"
$env:SCOOP_HOME = $env:SCOOP
$env:SCOOP_ROOT = $env:SCOOP

$env:HOME = $env:USERPROFILE

##### Functions #####
function Global:Get-Path ($command) {
    Get-Command $command -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty Definition 
}
function Global:New-Link ([switch] $s, [switch] $j, [switch] $d, [string] $filePath, [string] $symlink) {
    if ($s) {
        New-Item -ItemType SymbolicLink -Value $filePath -Path $symlink
    }
    elseif ($j) {
        New-Item -ItemType Junction -Value $filePath -Path $symlink
    }
    elseif ($d) {
        cmd /c "mklink /d $symlink $filepath"
    }
    else { 
        New-Item -ItemType HardLink -Value $filePath -Path $symlink 
    }
}
function Global:Invoke-As-Admin () {
    if ($args.count -eq 0) { gsudo; return }
    $cmd = $args -Join ' '
    gsudo "pwsh.exe -Login -Command { $cmd }"
}
function Global:Get-DirItem () {
    Get-ChildItem $args | Format-Wide Name -AutoSize
}

##### Alias #####
Set-Alias -Scope Global sudo Invoke-As-Admin
Set-Alias -Scope Global touch New-Item
Set-Alias -Scope Global wget Invoke-WebRequest
Set-Alias -Scope Global which Get-Path
Set-Alias -Scope Global ln New-Link
Set-Alias -Scope Global ls Get-DirItem
function Global:printenv { Get-ChildItem env: }
function Global:md5sum { Get-FileHash $arg -Algorithm MD5 }
function Global:sha1sum { Get-FileHash $args -Algorithm SHA1 }
function Global:sha256sum { Get-FileHash $args }
function Global:la { (Get-ChildItem -Force $args) | Format-Wide Name -AutoSize }
function Global:ll { Get-ChildItem -force $args }

##### Modules #####
if (-not (Get-Module -Name Terminal-Icons -ListAvailable)) {
    Install-Module -Name Terminal-Icons -Force -Scope CurrentUser
}
Import-Module -Name Terminal-Icons
if (Test-Path $env:SCOOP\shims\starship.exe -PathType Leaf) { Invoke-Expression (&starship init powershell) }
