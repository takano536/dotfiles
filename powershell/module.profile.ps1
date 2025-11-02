##### Import Modules #####
$activateCommands = @{
    'PSReadLine'          = 'Import-Module -Name PSReadLine'
    'CompletionPredictor' = 'Import-Module -Name CompletionPredictor'
    'PowerType'           = 'Enable-PowerType'
    'z'                   = 'Import-Module -Name z'
    'Terminal-Icons'      = 'if ($IsWindows) { Import-Module -Name Terminal-Icons }'
}
$alternateCommands = @{
    'z'                   = ". `"$PSScriptRoot\Funcs\Invoke-ZJump.ps1`""
    'Terminal-Icons'      = ". `"$PSScriptRoot\Funcs\Show-EmojiChildItem.ps1`""
}
$activateCommands.GetEnumerator() | ForEach-Object {
    $name = $_.Key
    $command = $_.Value
    $isAvailable = Get-Module -Name $name -ListAvailable
    $hasImported = (Get-Module).Name -contains $name

    if ($isAvailable -and -not $hasImported) {
        Invoke-Expression $command
    }
    elseif (-not $isAvailable -and $alternateCommands.ContainsKey($name)) {
        Invoke-Expression $alternateCommands[$name]
    }
}
