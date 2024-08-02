```powershell
Set-ExecutionPolicy Unrestricted -Scope Process -Force; Invoke-WebRequest -Uri https://raw.githubusercontent.com/takano536/dotfiles/main/install.ps1 -Headers @{"Cache-Control"="no-cache"} -OutFile install.ps1; if ($?) {.\install.ps1}; Remove-Item .\install.ps1
```
```sh
curl -sS https://raw.githubusercontent.com/takano536/dotfiles/main/install.sh -H 'Cache-Control: no-cache, no-store' | bash
```
```json
{ "toolkit.legacyUserProfileCustomizations.stylesheets": true }
```
