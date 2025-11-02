##### Alias #####
Set-Alias -Scope Global vi nvim
Set-Alias -Scope Global vim nvim

if ($IsMacOS) {
    # pass
}
elseif ($IsLinux) {
    $error.clear()
    try { Get-Command -All eza | Out-Null }
    catch {}
    if (!$error) { function Global:ls { eza --icons $args } }
    function Global:ll { ls -alF }
    function Global:la { ls -a }
    function Global:l { ls -l1F }
}
else {
    # Windows OS
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
        Get-ChildItem $args | Format-Wide -AutoSize
    }
    function Global:Invoke-As-Admin {
        param(
            [switch] $NoProfile
        )

        if ($args.count -eq 0) { gsudo; return }
        if ($NoProfile) { gsudo { Invoke-Expression $args[0] } -args ($args -join ' ') }
        else { gsudo --loadProfile { Invoke-Expression $args[0] } -args ($args -join ' ') }
    }

    Set-Alias -Scope Global -Name touch -Value New-Item
    Set-Alias -Scope Global -Name which -Value Get-Path
    Set-Alias -Scope Global -Name ln -Value New-Link
    Set-Alias -Scope Global -Name sudo -Value Invoke-As-Admin
    Set-Alias -Scope Global -Name ls -Value Get-DirItem -Option AllScope
    function Global:la { Get-ChildItem -Force $args | Format-Wide -AutoSize }
    function Global:ll { Get-ChildItem -Force $args }
    function Global:printenv { Get-ChildItem env: }
    function Global:md5sum { Get-FileHash $args -Algorithm MD5 }
    function Global:sha1sum { Get-FileHash $args -Algorithm SHA1 }
    function Global:sha256sum { Get-FileHash $args }
}
