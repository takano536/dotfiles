```powershell
Set-ExecutionPolicy Unrestricted -Scope Process -Force; Invoke-WebRequest -Uri https://raw.githubusercontent.com/takano536/dotfiles/main/install.ps1 -OutFile install.ps1; if ($?) {.\install.ps1}; Remove-Item .\install.ps1
```
```sh
curl -sS https://raw.githubusercontent.com/takano536/dotfiles/main/install.sh | sh
```
```json
{ "toolkit.legacyUserProfileCustomizations.stylesheets": true }
```
