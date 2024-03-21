### Added by Zinit's installer
if [[ ! -f $HOME/.local/share/zinit/zinit.git/zinit.zsh ]]; then
    print -P "%F{33} %F{220}Installing %F{33}ZDHARMA-CONTINUUM%F{220} Initiative Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
    command mkdir -p "$HOME/.local/share/zinit" && command chmod g-rwX "$HOME/.local/share/zinit"
    command git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git" && \
        print -P "%F{33} %F{34}Installation successful.%f%b" || \
        print -P "%F{160} The clone has failed.%f%b"
fi

source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# Load a few important annexes, without Turbo
# (this is currently required for annexes)
zinit light-mode for \
    zdharma-continuum/zinit-annex-as-monitor \
    zdharma-continuum/zinit-annex-bin-gem-node \
    zdharma-continuum/zinit-annex-patch-dl \
    zdharma-continuum/zinit-annex-rust

### End of Zinit's installer chunk

# Completion
autoload -Uz compinit && compinit                        # 補完機能の有効
eval `dircolors` && export ZLS_COLORS=$LS_COLORS         # 補完候補色付けの準備
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"  # 補完候補に色を付ける
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'      # lessとcdの引数入力時、小文字で打った文字列で補完した時に、小文字大文字両方のファイル名にマッチさせる
zstyle ':completion:*:default' menu select=2             # 補完候補を一覧から選択し、補完候補がn以上なければすぐに補完する
setopt no_beep                                           # 補完候補がないときなどにビープ音を鳴らさない
setopt auto_list                                         # 補完候補が複数ある時に、一覧表示
setopt auto_menu                                         # 補完候補が複数あるときに自動的に一覧表示する
setopt complete_in_word                                  # カーソル位置で補完する
setopt list_types                                        # 補完候補一覧でファイルの種別をマーク表示
setopt list_packed                                       # 補完候補を詰めて表示
setopt magic_equal_subst                                 # --prefix=の後のパスを補完

# History
setopt hist_ignore_space     # コマンドラインの先頭がスペースで始まる場合ヒストリに追加しない
setopt hist_no_store         # history (fc -l) コマンドをヒストリリストから取り除く
setopt hist_ignore_dups      # 直前と同じコマンドをヒストリに追加しない
setopt hist_verify           # ヒストリを呼び出してから実行する間に一旦編集
setopt extended_history      # zsh の開始, 終了時刻をヒストリファイルに書き込む
setopt hist_reduce_blanks    # 余分な空白は詰めて記録 
setopt hist_save_no_dups     # 古いコマンドと同じものは無視 
setopt hist_ignore_all_dups  # ヒストリに追加されるコマンド行が古いものと同じなら古いものを削除
setopt hist_expand           # 補完時にヒストリを自動的に展開     
setopt share_history         # シェルのプロセスごとに履歴を共有    
setopt append_history        # 複数の zsh を同時に使う時など history ファイルに上書きせず追加

# Others
autoload -U colors && colors  # 色の有効化
setopt always_last_prompt     # 無駄なスクロールを避ける
export REPORTTIME=3           # 実行したプロセスの消費時間が3秒以上かかったら
