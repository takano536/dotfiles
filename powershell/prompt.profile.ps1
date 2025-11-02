##### Starship #####
$error.clear()
Get-Command -All starship -ErrorAction SilentlyContinue | Out-Null
if (!$error) { Invoke-Expression (& starship init powershell); return }

### StarShipがインストールされていない場合は自前でプロンプトを作成 ###
. $PSScriptRoot\Funcs\Set-Prompt.ps1
