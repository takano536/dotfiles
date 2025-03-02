##### Set PowerShell to UTF-8 #####
[console]::InputEncoding = [console]::OutputEncoding = New-Object System.Text.UTF8Encoding

##### Set up profile #####
$profHome = $MyInvocation.MyCommand.Path | Split-Path -Parent
$profSuffix = "profile.ps1"
$scripts = New-Object System.Collections.Generic.List[string]

##### Add profiles #####
if ($IsMacOS) {} elseif ($IsLinux) { $osProfPath = "$profHome/linux.$profSuffix" } else { $osProfPath = "$profHome/windows.$profSuffix" }
if (Test-Path variable:osProfPath) { $scripts.Add($osProfPath) } # Load OS-specific profiles

$scripts.Add("$profHome/modules.$profSuffix")    # Load modules
$scripts.Add("$profHome/prompt.$profSuffix")     # Set prompt style
$scripts.Add("$profHome/alias.$profSuffix")      # Set aliases
$scripts.Add("$profHome/psreadline.$profSuffix") # Set PSReadLine options

##### Load scripts #####
$scripts | ForEach-Object { & $_ }
