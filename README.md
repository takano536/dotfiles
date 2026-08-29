# dotfiles

Windows / Linux で使っている個人用 dotfiles です。

[chezmoi](https://www.chezmoi.io/) で設定ファイルを管理し、bootstrap installer で
新しい環境をいつもの開発環境にセットアップできます。

## :sparkles: 主な設定

シェルやエディタだけでなく、普段使うターミナルやアプリの設定もまとめて管理しています。

| アプリ / ツール | 主な設定 |
|---|---|
| **PowerShell** | alias、環境変数、モジュール、プロンプトなどのシェル環境 |
| **bash** | alias、環境変数、shell option、CLIツール連携 |
| **fish** | alias、キーバインド、PATH、CLIツール連携、テーマ |
| **Starship** | Catppuccin Mocha ベースの Powerline スタイルのプロンプト。OS、shell、Git、言語、時刻、実行時間などを表示 |
| **Neovim** | Catppuccin、Treesitter、Lualine、Noice、Trouble、Rainbow Delimiters などを使った開発環境 |
| **Vim** | Vim用の基本的な編集環境 |
| **tmux** | Catppuccin Mocha のステータスライン、CPU / RAM / battery / uptime 表示、マウス操作 |
| **Git** | Git の共通設定 |
| **Windows Terminal** | Catppuccin Mocha、UDEV Gothic、Acrylic、PowerShell / Git Bash / WSL などのプロファイルとキーバインド |
| **Zed** | Catppuccin Latte / Mocha、UDEV Gothic、エディタUI、ローカルモデルを使った edit prediction |
| **Sublime Text** | Material Theme / ayu、UDEV Gothic、タブ・サイドバー・エディタUIなど |
| **Firefox** | `userChrome.css` / `userContent.css` / `user.js` によるブラウザUIと動作のカスタマイズ |

> [!NOTE]
> OSによって不要な設定は `.chezmoiignore` で除外されます。
> Windows / Linux のどちらでも同じ source state を使いつつ、それぞれの環境に必要な設定だけを適用します。

### :art: 見た目

全体的に **Catppuccin Mocha** を中心に揃えています。

Starship、Neovim、tmux、Windows Terminal などで共通した配色を使い、フォントは対応する環境で **UDEV Gothic 35NFLG** を使用しています。

見た目だけでなく、シェルの alias やキーバインド、CLIツールとの連携なども含めて、環境を入れ替えても普段の操作感をなるべく変えない構成にしています。

## :rocket: セットアップ

このリポジトリを clone またはダウンロードして、環境に合った installer を実行します。

### :window: Windows

Windows PowerShell 5.1 から実行します。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

Git / Scoop / chezmoi / PowerShell 7 は事前に必要ありません。
必要なツールは installer がまとめてセットアップします。

> [!NOTE]
> 管理者権限は必要ありません。

### :penguin: Linux

現在は **Debian 13 (trixie)** のみを正式サポートしています。

```bash
bash ./install.sh
```

普段使っているユーザーから実行してください。

> [!IMPORTANT]
> `sudo ./install.sh` や root shell からは実行しないでください。
> `apt-get` に必要な処理だけ installer 内部で権限を昇格します。

> [!WARNING]
> Debian 13 以外では、パッケージのインストールや dotfiles の適用を行わず終了します。

## :package: インストールされるもの

installer はおおまかに次の順番でセットアップします。

1. 実行環境とリポジトリをチェック
2. Required パッケージをインストール
3. Optional パッケージをインストール
4. chezmoi を準備
5. dotfiles を適用

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

## :gear: オプション

| Windows | Linux | 内容 |
|---|---|---|
| `-DryRun` | `--dry-run` | 変更せず実行内容を確認 |
| `-SkipPackages` | `--skip-packages` | chezmoi 以外のパッケージ導入をスキップ |
| `-SkipOptional` | `--skip-optional` | Optional パッケージをスキップ |
| `-SkipChezmoiInstall` | `--skip-chezmoi-install` | chezmoi の自動導入を無効化 |

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
