local wezterm = require 'wezterm'
local config = {}
if wezterm.config_builder then
  config = wezterm.config_builder()
end

-- hide title bar
config.window_decorations = 'RESIZE'
-- color scheme
config.color_scheme = 'Tokyo Night Storm (Gogh)'
-- font
config.font = wezterm.font_with_fallback({'CaskaydiaCove Nerd Font'})
config.font_size = 12.0
-- default shell
if wezterm.target_triple == 'x86_64-pc-windows-msvc' then
    config.default_prog = {'pwsh'}
else
    config.default_prog = {'zsh'}
end 
-- padding
config.window_padding = {
    left = 30,
    right = 30,
    top = 30,
    bottom = 10
}

return config
