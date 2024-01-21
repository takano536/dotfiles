" basic
set number
set autoindent
set smartindent
set tabstop=4
set softtabstop=4
set shiftwidth=4
set encoding=utf-8
set fileencodings=utf-8,cp932
set expandtab
set hlsearch
set wildmenu
set ruler
set history=1000
syntax enable

" disable plugin
let g:did_install_default_menus = 1
let g:did_install_syntax_menu   = 1
let g:did_indent_on             = 1
let g:did_load_filetypes        = 1
let g:did_load_ftplugin         = 1
let g:loaded_2html_plugin       = 1
let g:loaded_gzip               = 1
let g:loaded_man                = 1
let g:loaded_matchit            = 1
let g:loaded_matchparen         = 1
let g:loaded_netrwPlugin        = 1
let g:loaded_remote_plugins     = 1
let g:loaded_shada_plugin       = 1
let g:loaded_spellfile_plugin   = 1
let g:loaded_tarPlugin          = 1
let g:loaded_tutor_mode_plugin  = 1
let g:loaded_zipPlugin          = 1
let g:skip_loading_mswin        = 1

" plugins
if has('unix') | call plug#begin('$XDG_DATA_HOME/nvim/plugged') | endif
if has('win32') || has ('win64') | call plug#begin('$HOME\.config\nvim\plugged') | endif
Plug 'folke/tokyonight.nvim',
Plug 'nvim-lualine/lualine.nvim'
Plug 'nvim-tree/nvim-web-devicons'
Plug 'nvim-treesitter/nvim-treesitter'
Plug 'preservim/nerdtree'
Plug 'ryanoasis/vim-devicons'
Plug 'lambdalisue/glyph-palette.vim'
Plug 'folke/noice.nvim'
Plug 'MunifTanjim/nui.nvim'
call plug#end()

" noice
lua require("noice").setup()

" color scheme
set t_Co=256
set cursorline
colorscheme tokyonight
highlight Normal      ctermbg=NONE guibg=NONE
highlight NonText     ctermbg=NONE guibg=NONE
highlight SpecialKey  ctermbg=NONE guibg=NONE
highlight EndOfBuffer ctermbg=NONE guibg=NONE
highlight LineNr      ctermbg=NONE guibg=NONE
if exists('+termguicolors')
    let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
    let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"
    set termguicolors
endif

" nerdtree
let NERDTreeShowHidden=1
let g:NERDTreeDirArrowExpandable = '▸'
let g:NERDTreeDirArrowCollapsible = '▾'
nnoremap <C-t> :NERDTreeToggle<CR>
autocmd vimenter * if !argc() | NERDTree | endif
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif

" nerdtree glyph palette
augroup my-glyph-palette
    autocmd! *
    autocmd FileType fern call glyph_palette#apply()
    autocmd FileType nerdtree,startify call glyph_palette#apply()
augroup END

" lualine
lua require('lualine').setup{ options = { theme = 'tokyonight' } }

" viminfo path
set viminfo+=n$XDG_CACHE_HOME/nvim/viminfo

" key mapping
set whichwrap=b,s,<,>,[,] " move to next line & previous line

