##### Import Modules #####
$activateCommands = @{
    'PSReadLine'          = 'Import-Module -Name PSReadLine'
    'CompletionPredictor' = 'Import-Module -Name CompletionPredictor'
    'PowerType'           = 'Enable-PowerType'
    'z'                   = 'Import-Module -Name z'
    'Terminal-Icons'      = 'if ($IsWindows) { Import-Module -Name Terminal-Icons }'
}
$activateCommands.GetEnumerator() | ForEach-Object {
    $isAvailable = Get-Module -Name $_.Key -ListAvailable
    $hasImported = (Get-Module).Name.Contains($_.Key)
    if ($isAvailable -and !$hasImported) { Invoke-Expression $_.Value }
}
