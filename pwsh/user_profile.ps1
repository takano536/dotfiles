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
function appget{ Update-App $args }

##### Env #####
$env:LESSHISTFILE = "$env:XDG_CACHE_HOME\less\.lesshst"
$env:STARSHIP_CONFIG = "$env:XDG_CONFIG_HOME\starship\prompt.toml"

##### Others #####
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Import-Module "$($(Get-Item $(Get-Command scoop.ps1).Path).Directory.Parent.FullName)\modules\scoop-completion"
Import-Module -Name CompletionPredictor
Import-Module -Name posh-git
Import-Module -Name Terminal-Icons
Import-Module -Name z
Invoke-Expression (&starship init powershell)
