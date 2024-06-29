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

-- packerを使ってプラグインを読み込む
vim.cmd [[ packadd packer.nvim ]]
return require('packer').startup(function(use)

    -- カラースキーム
    use 'folke/tokyonight.nvim'
    require('tokyonight').setup({
        transparent = true,
        styles = {
            sidebars = 'transparent',
            floats   = 'transparent',
        },
    }) -- folke/tokyonight

    -- ステータスライン
    use 'nvim-lualine/lualine.nvim'
    custom_theme = require('lualine.themes.tokyonight') -- テーマを抽出
    custom_theme.normal.c.bg = 'None'                   -- 背景を透明化
    require('lualine').setup{ 
        options = { theme = custom_theme }
    }

    -- シンタックスハイライト
    use 'nvim-treesitter/nvim-treesitter' 
    
    -- UIデザイン
    use 'folke/trouble.nvim'   -- 通知デザイン
    use 'folke/noice.nvim'     -- コマンドパレット
    use 'MunifTanjim/nui.nvim' -- noice.nvimで必要
    use 'rcarriga/nvim-notify' -- noice.nvimで必要
    require('trouble').setup({
        views = {
            mini = {
                win_options = {
                    winblend = 0, -- 背景を透明化
                },
            },
        },
    }) -- folke/trouble
    require('noice').setup({
        views = {
            mini = {
                win_options = {
                    winblend = 0, -- 背景を透明化
                },
            },
        },
    }) -- folke/noice.nvim

end)
