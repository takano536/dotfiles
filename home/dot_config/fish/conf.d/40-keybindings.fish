# 単語単位で選択
bind ctrl-shift-left 'commandline -B >/dev/null 2>&1; or commandline -f begin-selection; commandline -f backward-word'
bind ctrl-shift-right 'commandline -B >/dev/null 2>&1; or commandline -f begin-selection; commandline -f forward-word'

# Shift を離して移動したら選択を解除
bind left end-selection backward-char
bind right end-selection forward-char
bind ctrl-left end-selection backward-word
bind ctrl-right end-selection forward-word

# 選択中は選択範囲を削除し、通常時は1文字削除
bind backspace 'if commandline -B >/dev/null 2>&1; commandline -f kill-selection end-selection; else; commandline -f backward-delete-char; end'
bind delete 'if commandline -B >/dev/null 2>&1; commandline -f kill-selection end-selection; else; commandline -f delete-char; end'

# Esc で選択を解除しつつ、Fish 標準の cancel 動作も維持
bind escape end-selection cancel