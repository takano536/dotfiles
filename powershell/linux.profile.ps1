##### Envs #####
if (Test-Path "$env:HOME/.bin") { $env:PATH += ";$env:HOME/.bin" }
if (Test-Path "$env:HOME/.local/bin") { $env:PATH += ";$env:HOME/.local/bin" }
if (Test-Path "$env:HOME/.local/lib") { $env:LD_LIBRARY_PATH += ";$env:HOME/.local/lib" }

$env:XDG_CONFIG_HOME = "$env:HOME/.config"
$env:XDG_CACHE_HOME = "$env:HOME/.cache"
$env:XDG_DATA_HOME = "$env:HOME/.local/share"
$env:XFG_STATE_HOME = "$env:HOME/.local/state"

if (Test-Path "$env:XDG_DATA_HOME/asdf") {
    $env:ASDF_DIR = "$XDG_DATA_HOME/asdf"
    $env:ASDF_DATA_DIR = "$XDG_DATA_HOME/asdf"
    $env:ASDF_CONFIG_FILE = "$XDG_CONFIG_HOME/asdf/.asdfrc"
}

if (Test-Path "$env:XDG_DATA_HOME/cargo") { $env:CARGO_HOME = "$XDG_DATA_HOME/cargo" }
if (Test-Path "$env:XDG_DATA_HOME/rustup") { $env:RUSTUP_HOME = "$XDG_DATA_HOME/rustup" }

$env:LESSHISTFILE = "$env:XDG_CACHE_HOME/less/history"
$env:STARSHIP_CONFIG = "$env:XDG_CONFIG_HOME/starship/prompt.toml"
$env:PYTHONSTARTUP = "$env:XDG_CONFIG_HOME/python/.pythonrc"

##### Aliases #####
$error.clear()
try { Get-Command -All eza | Out-Null }
catch {}
if (!$error) { function Global:ls { eza --icons $args } }
function Global:ll { ls -alF }
function Global:la { ls -a }
function Global:l { ls -l1F }

##### App init #####
if (Test-Path "$XDG_DATA_HOME/asdf") { & "$ASDF_DIR/asdf.ps1" }
