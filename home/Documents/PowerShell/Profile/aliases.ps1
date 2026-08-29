##### Alias #####
Set-Alias -Scope Global vi nvim
Set-Alias -Scope Global vim nvim

function Global:Get-CommandPath ($command) {
    Get-Command $command -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty Definition 
}
Set-Alias -Scope Global -Name touch -Value New-Item
Set-Alias -Scope Global -Name which -Value Get-CommandPath
function Global:printenv { Get-ChildItem env: }
function Global:ln { & "$PSScriptRoot\scripts\New-Link.ps1" @args }
function Global:sudo { & "$PSScriptRoot\scripts\Invoke-AsAdmin.ps1" @args }
function Global:la {
    Initialize-ChildItemIcons; Get-ChildItem -Force @args | Format-Wide -AutoSize
}
function Global:ll {
    Initialize-ChildItemIcons; Get-ChildItem -Force @args
}