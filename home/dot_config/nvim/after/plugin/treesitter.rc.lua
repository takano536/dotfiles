if vim.fn.has('win32') == 1 then
    vim.env.CC = 'gcc'
    vim.env.CXX = 'g++'
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
    'python',
    'regex',
    'ssh_config',
    'toml',
    'vim',
    'xml',
}

require('nvim-treesitter').install(langs)

vim.api.nvim_create_autocmd('FileType', {
    pattern = langs,
    callback = function()
        vim.treesitter.start()
    end,
})