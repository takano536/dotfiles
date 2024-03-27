##### Set PowerShell to UTF-8 #####
[console]::InputEncoding = [console]::OutputEncoding = New-Object System.Text.UTF8Encoding

##### Functions #####
function Get-Path ($command) {
    Get-Command $command -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty Definition 
}
function New-Link ([switch] $s, [switch] $j, [switch] $d, [string] $filePath, [string] $symlink) {
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
function Invoke-As-Admin () {
    if ($args.count -eq 0) { gsudo; return }
    $cmd = $args -Join ' '
    gsudo "pwsh.exe -Login -Command { $cmd }"
}
function Get-DirItem () {
    Get-ChildItem $args | Format-Wide Name -AutoSize
}
function Update-App ( [string]$app ) {
    $workspaceDirpath = "$env:USERPROFILE\Documents\Python\app-get"
    $pythonPath = "$workspaceDirpath\.app-get-venv\Scripts\python.exe"
    $scriptPath = "$workspaceDirpath\appget.py"
    & $pythonPath $scriptPath update $app
}

##### Alias #####
Set-Alias sudo Invoke-As-Admin
Set-Alias touch New-Item
Set-Alias wget Invoke-WebRequest
Set-Alias which Get-Path
Set-Alias ln New-Link
Set-Alias ls Get-DirItem
Set-Alias vi nvim
Set-Alias vim nvim
function printenv { Get-ChildItem env: }
function md5sum { Get-FileHash $arg -Algorithm MD5 }
function sha1sum { Get-FileHash $args -Algorithm SHA1 }
function sha256sum { Get-FileHash $args }
function la { (Get-ChildItem -Force $args) | Format-Wide Name -AutoSize }
function ll { Get-ChildItem -force $args }
function appget { Update-App $args }

##### Env #####
$env:LESSHISTFILE = "$env:XDG_CACHE_HOME\less\.lesshst"
$env:STARSHIP_CONFIG = "$env:XDG_CONFIG_HOME\starship\prompt.toml"

##### PSReadLineOption #####
Import-Module -Name PSReadLine
Import-Module -Name CompletionPredictor
Enable-PowerType
Set-PSReadLineOption -PredictionSource HistoryAndPlugin 
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadlineOption -HistoryNoDuplicates
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

##### Others #####
Import-Module -Name Terminal-Icons
Import-Module -Name z
Invoke-Expression (&starship init powershell)
