```powershell
Invoke-WebRequest `
    -Uri https://raw.githubusercontent.com/takano536/dotfiles/main/install.ps1 `
    -OutFile install.ps1; `
if ($?) { powershell -NoProfile -ExecutionPolicy Bypass -Command .\install.ps1 }
```
