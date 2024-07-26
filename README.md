```powershell
Set-ExecutionPolicy Unrestricted -Scope Process; Invoke-WebRequest -Uri https://raw.githubusercontent.com/takano536/dotfiles/main/install.ps1 -OutFile install.ps1; if ($?) {.\install.ps1}
```
```json
{ "toolkit.legacyUserProfileCustomizations.stylesheets": true }
```
