##### Starship #####
$error.clear()
try { Get-Command -All starship | Out-Null }
catch {}
if (!$error) { Invoke-Expression (& starship init powershell) }
