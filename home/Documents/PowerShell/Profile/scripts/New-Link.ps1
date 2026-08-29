[CmdletBinding(DefaultParameterSetName = 'HardLink')]
param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Target,

    [Parameter(Position = 1)]
    [string]$LinkName,

    [Parameter(Mandatory, ParameterSetName = 'SymbolicLink')]
    [Alias('s')]
    [switch]$Symbolic,

    [Parameter(Mandatory, ParameterSetName = 'Junction')]
    [Alias('j')]
    [switch]$Junction
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$itemType = switch ($PSCmdlet.ParameterSetName) {
    'SymbolicLink' { 'SymbolicLink' }
    'Junction' { 'Junction' }
    default { 'HardLink' }
}

if ($itemType -eq 'SymbolicLink') {
    $targetValue = $Target
    $defaultLinkName = [IO.Path]::GetFileName($Target.TrimEnd([char[]]@('\', '/')))
}
else {
    $targetItem = Get-Item -LiteralPath $Target -Force
    $targetValue = $targetItem.FullName
    $defaultLinkName = $targetItem.Name
}

if ($itemType -eq 'Junction' -and -not $targetItem.PSIsContainer) {
    throw "Cannot create a junction to a file: $Target"
}

if ($itemType -eq 'HardLink' -and $targetItem.PSIsContainer) {
    throw "Cannot create a hard link to a directory: $Target"
}

if (-not $LinkName) {
    $LinkName = $defaultLinkName
}

if (-not $LinkName) {
    throw "Cannot derive a link name from target: $Target"
}

if ($itemType -eq 'SymbolicLink') {
    $arguments = @(
        '-ItemType', 'SymbolicLink'
        '-Path', $LinkName
        '-Target', $targetValue
    )

    & "$PSScriptRoot\Invoke-AsAdmin.ps1" `
        -Command 'New-Item' `
        -Arguments $arguments

    return
}

New-Item `
    -ItemType $itemType `
    -Path $LinkName `
    -Target $targetValue
