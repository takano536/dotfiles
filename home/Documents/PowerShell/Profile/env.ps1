##### XDG base directories #####
$env:XDG_CACHE_HOME = "$HOME\.cache"
$env:XDG_CONFIG_HOME = "$HOME\.config"
$env:XDG_DATA_HOME = "$HOME\.local\share"
$env:XDG_STATE_HOME = "$HOME\.local\state"

##### CLI tools #####
$env:LESSHISTFILE = "$env:XDG_CACHE_HOME\less\.lesshst"
$env:STARSHIP_CONFIG = "$env:XDG_CONFIG_HOME\starship\prompt.toml"

##### Scoop #####
$env:SCOOP = "$env:LOCALAPPDATA\Programs\Scoop"

##### Python #####
$env:PYTHON_HISTORY = "$env:XDG_STATE_HOME\python\history"
