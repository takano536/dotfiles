local status, noice = pcall(require, 'noice')
if not status then
	return
end

noice.setup({
    views = { mini = { win_options = { winblend = 0 }}},
})
