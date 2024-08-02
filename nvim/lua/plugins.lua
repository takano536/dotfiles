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
require('packer').startup(function(use)
    
    -- プラグインマネージャー
    use 'wbthomason/packer.nvim'

    -- 起動画面
    use {
        'goolord/alpha-nvim',
        requires = 'nvim-tree/nvim-web-devicons',
    }

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

end)
