```powershell
Invoke-WebRequest `
    -Uri https://raw.githubusercontent.com/takano536/dotfiles/main/install.ps1 `
    -OutFile $env:USERPROFILE\Downloads\install.ps1; `
if ($?) { powershell -NoProfile -ExecutionPolicy Bypass $env:USERPROFILE\Downloads\install.ps1 }
```
