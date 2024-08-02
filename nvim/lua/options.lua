-- オプション
local opts = {

    -- UI
    number     = true, -- 行番号を表示
    hlsearch   = true, -- 結果結果をハイライト
    showmatch  = true, -- 括弧の対応関係を一瞬表示
    title      = true, -- タイトルバーにファイル名を表示
    cursorline = true, -- 現在のカーソルを強調表示

    -- 不透明度
    winblend = 0, -- ウィンドウ
    pumblend = 0, -- ポップアップメニュー

    -- ステータスバー
    wildmenu = true, -- 入力に応じた候補を表示
    ruler    = true, -- カーソルの位置を表示

    -- インデント
    smarttab    = true, -- 行の先頭でキーを入力すると、インデントの挿入になる
    autoindent  = true, -- 改行時に前行と同数のインデントを自動挿入
    smartindent = true, -- ブロックに応じて自動でインデントを自動挿入
    shiftwidth  = 4,    -- インデントに対する空白数
    tabstop     = 4,    -- '\t'に対する空白数
    softtabstop = 4,    -- Tabキーの入力に対する空白数
    expandtab   = true, -- Tabをスペースに置換

    -- エンコード
    encoding      = 'utf-8',       -- Vimの内部文字コード
    fileencoding  = 'utf-8',       -- 書き込み時の文字コード
    fileencodings = 'utf-8,cp932', -- 読み込み時の文字コード

}

-- 上記のオプションをセット
for k, v in pairs(opts) do vim.opt[k] = v end

-- 背景色透明化
vim.cmd[[ 
    highlight Normal      ctermbg=none guibg=none
    highlight NonText     ctermbg=none guibg=none
    highlight SpecialKey  ctermbg=none guibg=none
    highlight EndOfBuffer ctermbg=none guibg=none
    highlight LineNr      ctermbg=none guibg=none
    highlight CursorLine  ctermbg=none guibg=none
]]

-- シンタックスハイライト
vim.cmd[[ syntax enable ]]
