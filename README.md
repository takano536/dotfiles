# dotfiles

Windows / Linux で使っている個人用 dotfiles です。

[chezmoi](https://www.chezmoi.io/) で設定ファイルを管理し、bootstrap installer で
新しい環境をいつもの開発環境にセットアップできます。

## :sparkles: 主な設定

シェルやエディタだけでなく、普段使うターミナルやアプリの設定もまとめて管理しています。

| アプリ / ツール | 主な設定 |
|---|---|
| **[PowerShell](https://github.com/PowerShell/PowerShell)** | alias、環境変数、モジュール、プロンプトなどのシェル環境 |
| **[bash](https://www.gnu.org/software/bash/)** | alias、環境変数、shell option、CLIツール連携 |
| **[fish](https://github.com/fish-shell/fish-shell)** | alias、キーバインド、PATH、CLIツール連携、テーマ |
| **[Starship](https://github.com/starship/starship)** | Catppuccin Mocha ベースの Powerline スタイルのプロンプト。OS、shell、Git、言語、時刻、実行時間などを表示 |
| **[Neovim](https://github.com/neovim/neovim)** | Catppuccin、Treesitter、Lualine、Noice、Trouble、Rainbow Delimiters などを使った開発環境 |
| **[Vim](https://github.com/vim/vim)** | Vim用の基本的な編集環境 |
| **[tmux](https://github.com/tmux/tmux)** | Catppuccin Mocha のステータスライン、CPU / RAM / battery / uptime 表示、マウス操作 |
| **[Git](https://git-scm.com/)** | Git の共通設定 |
| **[Windows Terminal](https://github.com/microsoft/terminal)** | Catppuccin Mocha、UDEV Gothic、Acrylic、PowerShell / Git Bash / WSL などのプロファイルとキーバインド |
| **[Zed](https://github.com/zed-industries/zed)** | Catppuccin Latte / Mocha、UDEV Gothic、エディタUI、ローカルモデルを使った edit prediction |
| **[Sublime Text](https://www.sublimetext.com/)** | Material Theme / ayu、UDEV Gothic、タブ・サイドバー・エディタUIなど |
| **[Firefox](https://www.mozilla.org/firefox/)** | `userChrome.css` / `userContent.css` / `user.js` によるブラウザUIと動作のカスタマイズ |

> [!NOTE]
> OSによって不要な設定は `.chezmoiignore` で除外されます。
> Windows / Linux のどちらでも同じ source state を使いつつ、それぞれの環境に必要な設定だけを適用します。

### :art: 見た目

全体的に **[Catppuccin](https://github.com/catppuccin/catppuccin) Mocha** を中心に揃えています。

[Starship](https://github.com/starship/starship)、[Neovim](https://github.com/neovim/neovim)、
[tmux](https://github.com/tmux/tmux)、[Windows Terminal](https://github.com/microsoft/terminal)
などで共通した配色を使い、フォントは対応する環境で
**[UDEV Gothic](https://github.com/yuru7/udev-gothic) 35NFLG** を使用しています。

見た目だけでなく、シェルの alias やキーバインド、CLIツールとの連携なども含めて、
環境を入れ替えても普段の操作感をなるべく変えない構成にしています。

## :rocket: セットアップ

リポジトリの clone は不要です。installer を直接実行すると、必要なら installer が
自分で dotfiles リポジトリを取得します。

### :window: Windows

Windows PowerShell から実行します (PowerShell 7 でも可)。

```powershell
$f = Join-Path $env:TEMP ('dotfiles-install-' + [Guid]::NewGuid().ToString('N').Substring(0, 8) + '.ps1'); [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/takano536/dotfiles/main/install.ps1' -OutFile $f; powershell.exe -NoProfile -ExecutionPolicy Bypass -File $f
```

Git / Scoop / chezmoi / PowerShell 7 は事前に必要ありません。
必要なツールは installer がまとめてセットアップします。

> [!NOTE]
> 管理者権限は必要ありません。
> installer 本体は Windows PowerShell 5.1 で実行されます。

> [!NOTE]
> `irm ... | iex` 形式は採用していません。`install.ps1` は `param` ブロックと
> `#Requires -Version 5.1` を持つスクリプトファイルであり、pipe 経由では
> オプションを渡せず、`#Requires` も無視されるためです。
> 一度ファイルへ保存してから `-File` で実行します。

> [!WARNING]
> 上記は PowerShell プロンプトに貼り付ける前提のコマンドです。
> cmd.exe から実行する場合は、下の「ダウンロードして内容を確認してから実行する」を使ってください。

> [!NOTE]
> ダウンロード先は毎回新しいファイル名にしています。
> `%TEMP%` に古いコピーや第三者が置いたファイルがあっても、それを実行しません。

### :penguin: Linux

現在は **Debian 13 (trixie)** のみを正式サポートしています。

```bash
curl -fsSL https://raw.githubusercontent.com/takano536/dotfiles/main/install.sh | bash
```

普段使っているユーザーから実行してください。

> [!IMPORTANT]
> `sudo` 付きや root shell からは実行しないでください。
> `apt-get` に必要な処理だけ installer 内部で権限を昇格します。

> [!WARNING]
> Debian 13 以外では、パッケージのインストールや dotfiles の適用を行わず終了します。

### :mag: ダウンロードして内容を確認してから実行する

installer は remote code execution の入口になるため、実行前に内容を確認できます。

**Windows**

```powershell
$u = 'https://raw.githubusercontent.com/takano536/dotfiles/main/install.ps1'
$f = Join-Path $env:TEMP ('dotfiles-install-' + [Guid]::NewGuid().ToString('N').Substring(0, 8) + '.ps1')
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -UseBasicParsing $u -OutFile $f
notepad $f
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $f
```

**Linux**

```bash
curl -fsSL -o "$HOME/dotfiles-install.sh" https://raw.githubusercontent.com/takano536/dotfiles/main/install.sh
less "$HOME/dotfiles-install.sh"
bash "$HOME/dotfiles-install.sh"
```

### :package: installer が取得するリポジトリ

clone が必要な場合、installer は chezmoi の標準の source directory
`~/.local/share/chezmoi` に `https://github.com/takano536/dotfiles.git` (branch `main`)
を clone し、その clone の installer に処理を引き継ぎます。

すでに clone がある場合は、そのまま使います。

| 状態 | 挙動 |
|---|---|
| このリポジトリの clone がある | そのまま使用。clone も pull もしない |
| 未コミットの変更がある | そのまま使用。変更には触らず、注意点として報告 |
| 別のリポジトリの clone がある | 中断。復旧方法を表示 |
| dotfiles 以外のファイルがある | 中断。復旧方法を表示 |
| 空のディレクトリだけがある | そこへ clone |

> [!IMPORTANT]
> 既存のディレクトリを削除・上書きしたり、`git reset` などで変更を捨てることはありません。
> 危険な状態では停止し、対処方法を表示します。

### :file_folder: clone 済みリポジトリから実行する

従来どおり、checkout の中から直接実行できます。この場合は再取得を行いません。

**Windows**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

**Linux**

```bash
bash ./install.sh
```

## :package: インストールされるもの

installer はおおまかに次の順番でセットアップします。

1. 実行環境をチェック
2. リポジトリを用意 (clone 済みならそのまま使用)
3. Required パッケージをインストール
4. Optional パッケージをインストール
5. chezmoi を準備
6. dotfiles を適用

> [!IMPORTANT]
> Required パッケージの導入に失敗した場合は、dotfiles を適用せず終了します。
> Optional パッケージの失敗は警告として記録し、残りのセットアップを続行します。

### 主なツール

| カテゴリ | ツール |
|---|---|
| Shell | PowerShell / bash / fish / Starship |
| Editor | Neovim |
| Git | Git / delta / lazygit / gh |
| CLI | zoxide / eza / bat / ripgrep / fd / fzf / jq |
| TUI | btop / yazi / fastfetch |

正確なパッケージ一覧は [`packages/`](packages/) で管理しています。

## :mag: Dry run

実際に変更する前に、installer が何を行うか確認できます。

**Windows**

```powershell
.\install.ps1 -DryRun
```

**Linux**

```bash
bash ./install.sh --dry-run
```

> [!NOTE]
> clone が済んでいない状態の dry run では、clone 予定の内容だけを表示して終了します。
> 全体の計画を見るには、先に clone してから clone の中で dry run を実行してください。

## :gear: オプション

| Windows | Linux | 内容 |
|---|---|---|
| `-DryRun` | `--dry-run` | 変更せず実行内容を確認 |
| `-SkipPackages` | `--skip-packages` | chezmoi 以外のパッケージ導入をスキップ |
| `-SkipOptional` | `--skip-optional` | Optional パッケージをスキップ |
| `-SkipChezmoiInstall` | `--skip-chezmoi-install` | chezmoi の自動導入を無効化 |

clone せずに実行する場合のオプションの渡し方です。

```bash
curl -fsSL https://raw.githubusercontent.com/takano536/dotfiles/main/install.sh | bash -s -- --dry-run
```

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $f -DryRun
```

`$f` はダウンロード手順で installer を保存したパスです。

## :computer: サポート環境

| 環境 | サポート |
|---|---|
| Windows | :white_check_mark: |
| Debian 13 (trixie) | :white_check_mark: |
| その他の Linux | :x: |

> [!NOTE]
> Linux installer は意図的に Debian 13 専用にしています。
> 他の package manager へ fallback することはありません。

## :file_folder: リポジトリ構成

```text
.
├── home/                 # chezmoi source state
├── packages/
│   ├── windows.psd1      # Windows package definitions
│   └── linux.tsv         # Debian package definitions
├── tests/                # installer / dotfiles tests
├── install.ps1           # Windows bootstrap
├── install.sh            # Debian bootstrap
└── .github/
    └── workflows/        # CI
```
