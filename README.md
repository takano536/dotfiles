```powershell
Set-ExecutionPolicy Unrestricted -Scope Process -Force; Invoke-WebRequest -Uri https://raw.githubusercontent.com/takano536/dotfiles/main/install.ps1 -OutFile install.ps1; if ($?) {.\install.ps1}
```
```powershell
Set-ExecutionPolicy Unrestricted -Scope Process -Force; Invoke-WebRequest -Headers @{"Cache-Control"="no-cache"} -Uri https://raw.githubusercontent.com/takano536/dotfiles/main/install.ps1 -OutFile install.ps1; if ($?) {.\install.ps1}
```
```json
{ "toolkit.legacyUserProfileCustomizations.stylesheets": true }
```
