##### Starship #####
if (Get-Command starship -CommandType Application -ErrorAction SilentlyContinue) {
    Invoke-Expression (& starship init powershell)
}
else {
    # StarShipがインストールされていない場合は自前でプロンプトを作成
    . (Join-Path $PSScriptRoot 'scripts\Set-Prompt.ps1')
}