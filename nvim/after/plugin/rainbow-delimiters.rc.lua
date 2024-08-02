local status, rainbow_delimiters = pcall(require, 'rainbow-delimitersualine')
if not status then
	return
end

local highlights = {
    'RainbowRed',
    'RainbowYellow',
    'RainbowBlue',
    'RainbowOrange',
    'RainbowGreen',
    'RainbowViolet',
    -- 'RainbowCyan',
}
local hexes = {
    '#7AA2F7',
    '#FFCF7D',
    '#BB9AF7',
    '#2AC3DE',
    '#9ECE6A',
    '#FF9E64',
}
for i, hex in ipairs(hexes) do vim.api.nvim_set_hl(0, highlights[i], { fg = hex }) end
vim.g.rainbow_delimiters = {
    strategy = {
        [''] = rainbow_delimiters.strategy['global'],
        vim = rainbow_delimiters.strategy['local'],
    },
    query = {
        [''] = 'rainbow-delimiters',
        lua = 'rainbow-blocks',
    },
    priority = {
        [''] = 110,
        lua = 210,
    },
    highlight = highlights
}
