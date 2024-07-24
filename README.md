```powershell
Invoke-WebRequest -Uri https://raw.githubusercontent.com/takano536/dotfiles/main/install.ps1 -OutFile install.ps1; if ($?) { Start-Process powershell.exe -ArgumentList "/noexit", "-executionpolicy bypass",".\\install.ps1" }
```
