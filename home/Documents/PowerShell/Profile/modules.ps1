##### Import Modules #####
if ($PSVersionTable.PSVersion.Major -ge 7) {
    Import-Module CompletionPredictor
    Import-Module PowerType
    Enable-PowerType
}

##### Lazy Terminal Icons #####
function Global:Initialize-ChildItemIcons {
    if ($global:_ChildItemIconsInitialized) {
        return
    }
    Import-Module Terminal-Icons
    $global:_ChildItemIconsInitialized = $true
}