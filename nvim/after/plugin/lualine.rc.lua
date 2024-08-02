local status, lualine = pcall(require, 'lualine')
if not status then
	return
end

local custom_theme = require('lualine.themes.tokyonight')
custom_theme.normal.c.bg = 'None'
lualine.setup{ 
    options = { theme = custom_theme }
}
