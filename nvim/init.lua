-- pythonパス
if vim.fn.has('win32') or vim.fn.has ('win64') then
    vim.g['python3_host_prog'] = '$HOME\\AppData\\Local\\nvim-data\\venv\\Scripts\\python.exe'
end

require('plugins')
require('options')
require('keymaps')
