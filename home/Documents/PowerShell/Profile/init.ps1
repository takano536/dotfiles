##### Set PowerShell to UTF-8 #####
$utf8 = New-Object System.Text.UTF8Encoding
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8

##### Load profile #####
$profiles = @(
    'env.ps1'
    'prompt.ps1'
    'modules.ps1'
    'aliases.ps1'
    'psreadline.ps1'
)
$profiles | ForEach-Object { . (Join-Path $PSScriptRoot $_) }
