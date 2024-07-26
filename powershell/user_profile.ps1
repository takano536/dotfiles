##### Set PowerShell to UTF-8 #####
[console]::InputEncoding = [console]::OutputEncoding = New-Object System.Text.UTF8Encoding

##### Alias #####
Set-Alias -Scope Global vi nvim
Set-Alias -Scope Global vim nvim

##### Install Modules #####
$modules = @{
    'PSReadLine'          = 5.1
    'CompletionPredictor' = 7.2
    'PowerType'           = 7.2
    'Terminal-Icons'      = 5.1
    'z'                   = 7.2
}
$PSVersion=$PSVersionTable.PSVersion.Major,$PSVersionTable.PSVersion.Minor -join '.'
$modules.GetEnumerator() | ForEach-Object {
    if ($PSVersion -lt $_.Value) { continue }
    $hasInstalled = Get-Module -Name $_.Key -ListAvailable
    if (!$hasInstalled) { Install-Module -Name $_.Key -Force -Scope CurrentUser }
}

##### Import Modules #####
$modules = @{
    'PSReadLine'          = 'Import-Module -Name PSReadLine'
    'CompletionPredictor' = 'Import-Module -Name CompletionPredictor'
    'PowerType'           = 'Enable-PowerType'
    'z'                   = 'Import-Module -Name z'
}
$modules.GetEnumerator() | ForEach-Object {
    $isAvailable = Get-Module -Name $_.Key -ListAvailable
    $hasImported = (Get-Module).Name.Contains($_.Key)
    if ($isAvailable -and !$hasImported) { Invoke-Expression $_.Value }
}

##### PSReadLineOption #####
if ($PSVersionTable.PSVersion.Major -ge 7) { 
    Set-PSReadLineOption -PredictionSource HistoryAndPlugin
    Set-PSReadLineOption -PredictionViewStyle ListView
}
Set-PSReadlineOption -HistoryNoDuplicates
Set-PSReadlineOption -EditMode Windows
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineKeyHandler `
    -Key "(", "{", "[" `
    -BriefDescription "InsertPairedBraces" `
    -LongDescription "Insert matching braces or wrap selection by matching braces" `
    -ScriptBlock {
        
    param($key, $arg)
    $openChar = $key.KeyChar
    $closeChar = switch ($openChar) {
        <#case#> "(" { [char]")"; break }
        <#case#> "{" { [char]"}"; break }
        <#case#> "[" { [char]"]"; break }
    }

    $selectionStart = $null
    $selectionLength = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selectionStart, [ref]$selectionLength)
    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    if ($selectionStart -ne -1) {
        [Microsoft.PowerShell.PSConsoleReadLine]::Replace($selectionStart, $selectionLength, $openChar + $line.SubString($selectionStart, $selectionLength) + $closeChar)
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($selectionStart + $selectionLength + 2)
        return
    }
    $nOpen = [regex]::Matches($line, [regex]::Escape($openChar)).Count
    $nClose = [regex]::Matches($line, [regex]::Escape($closeChar)).Count
    if ($nOpen -ne $nClose) {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($openChar)
    }
    else {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($openChar + $closeChar)
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor - 1)
    }
}
Set-PSReadLineKeyHandler `
    -Key ")", "]", "}" `
    -BriefDescription "SmartCloseBraces" `
    -LongDescription "Insert closing brace or skip" `
    -ScriptBlock {

    param($key, $arg)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    if ($line[$cursor] -eq $key.KeyChar) {
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
    }
    else {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($key.KeyChar)
    }
}
Set-PSReadLineKeyHandler -Key "`"", "'" `
    -BriefDescription "smartQuotation" `
    -LongDescription "Put quotation marks and move the cursor between them or put marks around the selection" `
    -ScriptBlock {

    param($key, $arg)
    $mark = $key.KeyChar

    $selectionStart = $null
    $selectionLength = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selectionStart, [ref]$selectionLength)
    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    if ($selectionStart -ne -1) {
        [Microsoft.PowerShell.PSConsoleReadLine]::Replace($selectionStart, $selectionLength, $mark + $line.SubString($selectionStart, $selectionLength) + $mark)
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($selectionStart + $selectionLength + 2)
        return
    }

    if ($line[$cursor] -eq $mark) {
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
        return
    }

    $nMark = [regex]::Matches($line, $mark).Count
    if ($nMark % 2 -eq 1) {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($mark)
    }
    else {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($mark + $mark)
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor - 1)
    }
}
Set-PSReadLineKeyHandler `
    -Key Backspace `
    -BriefDescription SmartBackspace `
    -LongDescription "Delete previous character or matching quotes/parens/braces" `
    -ScriptBlock {
    
    param($key, $arg)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    if ($cursor -gt 0) {
        $toMatch = $null
        if ($cursor -lt $line.Length) {
            switch ($line[$cursor]) {
                <#case#> '"' { $toMatch = '"'; break }
                <#case#> "'" { $toMatch = "'"; break }
                <#case#> ')' { $toMatch = '('; break }
                <#case#> ']' { $toMatch = '['; break }
                <#case#> '}' { $toMatch = '{'; break }
            }
        }

        if ($toMatch -ne $null -and $line[$cursor - 1] -eq $toMatch) {
            [Microsoft.PowerShell.PSConsoleReadLine]::Delete($cursor - 1, 2)
        }
        else {
            [Microsoft.PowerShell.PSConsoleReadLine]::BackwardDeleteChar($key, $arg)
        }
    }
}

##### Load OS-specific profile #####
if (($PSVersionTable.PSVersion.Major -le 5) -or $IsWindows) {
    & "$env:USERPROFILE/.config/powershell/windows_profile.ps1"
}
elseif ($IsLinux) {
    & "$HOME/.config/powershell/linux_profile.ps1"
}
