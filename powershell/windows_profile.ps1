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
function Global:New-Link {
    param(
        [Parameter(Mandatory = $true)] [string]$Target,
        [string]$LinkName,
        [switch]$Symbolic,
        [switch]$Junction
    )

    $isEmptyLinkName = -not $LinkName
    if (-not $isEmptyLinkName) {
        $linkDir = Split-Path $LinkName
        $isEmptyLinkDir = -not $linkDir
        if (-not $isEmptyLinkDir -and -not (Test-Path $linkDir)) { throw "No such file or directory: $linkDir" }
    }

    $workingDir = Get-Location
    if ($isEmptyLinkName) {
        $targetName = Split-Path $Target -Leaf
        $LinkName = Join-Path $workingDir $targetName 
    }
    else {
        $linkDir = Split-Path $LinkName
        if (-not $linkDir -or -not (Test-Path $linkDir)) { $LinkName = Join-Path $workingDir $LinkName }
    }

    $linkDir = Split-Path $LinkName
    $isDir = Test-Path $Target -PathType Container
    if (-not (Test-Path $linkDir)) { throw "No such file or directory: $linkDir" }
    if (-not (Test-Path $Target)) { throw "No such file or directory: $Target" }
    if ($Junction -and (-not $isDir)) { throw "Cannot create a junction to a file: $Target" }

    if ($Symbolic) {
        gsudo { New-Item -ItemType SymbolicLink -Path $args[0] -Value $args[1] } -args $LinkName, $Target
    }
    elseif ($Junction) {
        New-Item -ItemType Junction -Path $LinkName -Value $Target
    }
    else {
        New-Item -ItemType HardLink -Path $LinkName -Value $Target
    }
}
function Global:Get-DirItem () {
    Get-ChildItem $args | Format-Wide Name -AutoSize
}
function Global:Invoke-As-Admin {
    param(
        [switch] $NoProfile
    )

    if ($args.count -eq 0) { gsudo; return }
    if ($NoProfile) { gsudo { Invoke-Expression $args[0] } -args ($args -join ' ') }
    else { gsudo --loadProfile { Invoke-Expression $args[0] } -args ($args -join ' ') }
}

##### Alias #####
if ($PSVersionTable.PSVersion.Major -ge 7) { 
    Set-Alias -Scope Global wget Invoke-WebRequest 
    Set-Alias -Scope Global ls Get-DirItem
}
Set-Alias -Scope Global touch New-Item
Set-Alias -Scope Global which Get-Path
Set-Alias -Scope Global ln New-Link
Set-Alias -Scope Global sudo Invoke-As-Admin
function Global:printenv { Get-ChildItem env: }
function Global:md5sum { Get-FileHash $args -Algorithm MD5 }
function Global:sha1sum { Get-FileHash $args -Algorithm SHA1 }
function Global:sha256sum { Get-FileHash $args }
function Global:la { (Get-ChildItem -Force $args) | Format-Wide Name -AutoSize }
function Global:ll { Get-ChildItem -force $args }

##### Modules #####
$activateCommands = @{
    'Terminal-Icons' = 'Import-Module -Name Terminal-Icons'
}
$activateCommands.GetEnumerator() | ForEach-Object {
    $isAvailable = Get-Module -Name $_.Key -ListAvailable
    $hasImported = (Get-Module).Name.Contains($_.Key)
    if ($isAvailable -and !$hasImported) { Invoke-Expression $_.Value }
}
if (Test-Path $env:SCOOP\shims\starship.exe -PathType Leaf) { Invoke-Expression (&starship init powershell) }
