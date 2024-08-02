local status, tokyonight = pcall(require, 'tokyonight')
if not status then
	return
end

tokyonight.setup({
    transparent = true,
    styles = {
        sidebars = 'transparent',
        floats   = 'transparent',
    },
})

-- カラースキームの設定
vim.cmd[[ colorscheme tokyonight-storm ]]
