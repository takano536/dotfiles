local status, treesitter = pcall(require, 'nvim-treesitter')
if not status then
	return
end

local langs = {
    'bash',
    'c',
    'cmake',
    'cpp',
    'csv',
    'gitignore',
    'json',
    'lua',
    'make',
    'matlab',
    'python',
    'ssh_config',
    'toml',
    'vim',
    'xml',
}
treesitter.setup {
    highlight = { enable = true },
    ensure_installed = langs,
}
