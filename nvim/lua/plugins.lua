-- 無効化する標準プラグイン
local plugs = {
    'did_install_default_menus',
    'did_install_syntax_menu',
    'did_indent_on',
    'did_load_filetypes',
    'did_load_ftplugin',
    'loaded_2html_plugin',
    'loaded_gzip',
    'loaded_man',
    'loaded_matchit',
    'loaded_matchparen',
    'loaded_netrwPlugin',
    'loaded_remote_plugins',
    'loaded_shada_plugin',
    'loaded_spellfile_plugin',
    'loaded_tarPlugin',
    'loaded_tutor_mode_plugin',
    'loaded_zipPlugin',
    'skip_loading_mswin',
}

-- 高速化のため上記のプラグインを無効化
for _, plug in ipairs(plugs) do vim.g[plug] = 1 end


-- プラグインの自動インストール用関数
local ensure_packer = function()
    local fn = vim.fn
    local install_path = fn.stdpath('data')..'/site/pack/packer/start/packer.nvim'
    if fn.empty(fn.glob(install_path)) > 0 then
        fn.system({'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path})
        vim.cmd [[packadd packer.nvim]]
        return true
    end
    return false
end
local packer_bootstrap = ensure_packer()

-- packerを使ってプラグインを読み込む
vim.cmd [[ packadd packer.nvim ]]
require('packer').startup(function(use)

    -- カラースキーム
    use 'folke/tokyonight.nvim'

    -- ステータスライン
    use 'nvim-lualine/lualine.nvim'

    -- シンタックスハイライト
    use 'nvim-treesitter/nvim-treesitter' 

    -- 括弧の色付け
    use 'HiPhish/rainbow-delimiters.nvim'
    
    -- UIデザイン
    use 'folke/trouble.nvim'   -- 通知デザイン
    use 'folke/noice.nvim'     -- コマンドパレット
    use 'MunifTanjim/nui.nvim' -- noice.nvimで必要
    use 'rcarriga/nvim-notify' -- noice.nvimで必要

    -- Automatically set up your configuration after cloning packer.nvim
    -- Put this at the end after all plugins
    if packer_bootstrap then
        require('packer').sync()
    end

end)

-- tokyonight
require('tokyonight').setup({
    transparent = true,
    styles = {
        sidebars = 'transparent',
        floats   = 'transparent',
    },
})

-- lualine
local custom_theme = require('lualine.themes.tokyonight')
custom_theme.normal.c.bg = 'None'
require('lualine').setup{ 
    options = { theme = custom_theme }
}

-- nvim-treesitter
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
require('nvim-treesitter.configs').setup {
    highlight = { enable = true },
    ensure_installed = langs,
}

-- rainbow-delimiters
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
local rainbow_delimiters = require 'rainbow-delimiters'
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

-- noice
require('noice').setup({
    views = { mini = { win_options = { winblend = 0 }}},
})

-- trouble
require('trouble').setup({
    views = { mini = { win_options = { winblend = 0 }}},
})
