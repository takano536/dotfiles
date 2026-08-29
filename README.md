# dotfiles

[chezmoi](https://www.chezmoi.io/) で管理している dotfiles と、Windows 用の
bootstrap installer。

- `home/` … chezmoi の source state（`.chezmoiroot` でここが source directory になる）
- `install.ps1` … Windows 用のセットアップスクリプト
- `packages/windows.psd1` … `install.ps1` が導入するパッケージ定義
- `tests/` … `install.ps1` と パッケージ定義の Pester テスト

## セットアップ（Windows）

```powershell
git clone git@github.com:takano536/dotfiles.git
cd dotfiles
.\install.ps1
```

前提は **リポジトリを取得できていること**（= Git があるか、ZIP を展開したこと）
だけ。Scoop も chezmoi も無い環境で実行できる。管理者権限は不要。

`install.ps1` の処理順:

1. リポジトリルートの解決（`.chezmoiroot` と `packages/windows.psd1` を検証）
2. 前提確認（PowerShell / OS の表示、Scoop ルートの決定）
3. Scoop の確保（無ければ公式 installer で `%LOCALAPPDATA%\Programs\Scoop` に導入）
4. Scoop bucket の確保（`main`、`extras`）
5. Required パッケージの導入
6. Optional パッケージの導入
7. PowerShell モジュールの導入（`pwsh` 経由）
8. chezmoi の確保
9. `chezmoi init --apply --source <リポジトリのパス>`
10. サマリ表示

`home/.chezmoi.toml.tmpl` により chezmoi 設定へ `sourceDir` が記録されるので、
以後は `chezmoi apply` / `chezmoi diff` を素で実行できる。

### インストール対象

パッケージ一覧は `packages/windows.psd1`（`Import-PowerShellDataFile` で読む
データのみのファイル）が唯一の定義元。`install.ps1` にパッケージ名は書かない。

**Required** … 適用した dotfiles が壊れる/既定動作に落ちるもの。導入に失敗したら
installer 全体を失敗（exit 1）扱いにする。

| package | 理由 |
|---|---|
| `git` | Windows Terminal の Git Bash プロファイル、`.bashrc`、chezmoi の source 更新 |
| `pwsh` | Windows Terminal の既定プロファイル、`Documents/PowerShell` の profile |
| `neovim` | PowerShell / bash の `vi` `vim` alias、`.config/nvim` |
| `starship` | `prompt.ps1` と `bash/tools.bash`、`.config/starship` |
| `chezmoi` | このリポジトリの適用 |

**Optional** … 日常的に使う CLI / TUI と、Neovim 設定が使う補助ツール。失敗しても
他のパッケージは続行し、最後のサマリに失敗パッケージを表示する（installer 自体は
成功扱い）。

`zoxide` `eza` `tree-sitter` `gcc` `ripgrep` `fd` `fzf` `bat` `jq` `delta`
`lazygit` `gh` `btop` `yazi` `fastfetch`

（`zoxide` / `eza` は bash 設定が参照、`tree-sitter` / `gcc` は
`nvim/after/plugin/treesitter.rc.lua` が Windows で `CC=gcc` を設定して parser を
ビルドするため。）

**PowerShell モジュール** … `Documents/PowerShell/Profile/modules.ps1` が無条件に
`Import-Module` するもの: `Terminal-Icons` `CompletionPredictor` `PowerType`。
PowerShell 7 のモジュールパスへ入れる必要があるため、`pwsh` を呼び出して
`Install-Module -Scope CurrentUser` する（既に入っていれば何もしない）。

### インストールしないもの

**AI coding agent（Oh My Pi / `omp`、Claude Code、Codex CLI など）は入らない。**
そのほか以下も対象外:

- Docker / WSL ディストリビューション / サーバー用途のソフトウェア
- GUI アプリと IDE（Firefox、Sublime Text、Zed、Windows Terminal 本体）
- フォント（Windows Terminal が指定する `UDEV Gothic 35NFLG` は手動導入）
- SSH 鍵、Git credential、API key などの認証情報
- Bun / Node.js / Python などのランタイム（Windows 側の dotfiles が必要としない。
  Bun は fish 設定のみで参照され、fish は `.chezmoiignore` により Windows では
  適用されない）
- Windows の OS 設定変更

この方針はテストでも固定してある（`packages/windows.psd1` に上記の名前が現れたら
テストが失敗する）。

### オプション

```powershell
.\install.ps1 -DryRun              # 計画のみ表示、何もインストールせず HOME も変更しない
.\install.ps1 -SkipPackages        # chezmoi 以外のパッケージ導入を行わない
.\install.ps1 -SkipOptional        # Required だけ入れ、CLI / TUI は入れない
.\install.ps1 -SkipChezmoiInstall  # chezmoi が無い場合に自動導入せずエラー終了
.\install.ps1 -Verbose             # chezmoi の適用内容を表示
```

`-DryRun` では、導入予定のパッケージ・利用予定のパッケージマネージャ
（scoop / winget）・追加予定の bucket・Scoop bootstrap の予定・chezmoi の
適用予定（`chezmoi --dry-run`）が表示されるだけで、パッケージ導入も HOME の変更も
行われない。

### 冪等性

何度実行しても安全。

- パッケージは `%SCOOP%\apps\<name>\current` の有無と command の解決結果で判定し、
  導入済みなら再インストールしない（shim を作らない manifest や、shim 作成直後で
  PATH が未更新の場合も検出できる）
- bucket は `%SCOOP%\buckets\<name>` があれば再追加しない
- PATH や設定ファイルへの追記は行わない（`chezmoi apply` と Scoop に任せる）
- chezmoi 自体が冪等

### Scoop / winget の方針

Windows では Scoop を第一選択とする（この dotfiles は `$env:SCOOP` を
`%LOCALAPPDATA%\Programs\Scoop` に固定し、Windows Terminal もその下の
`pwsh` / `git` を参照しているため）。

Scoop が無い場合は公式 installer（Scoop プロジェクトの配布元
`https://get.scoop.sh`）を使う。`iex (irm ...)` は使わず、

1. TLS 1.2 を有効化（Windows PowerShell 5.1 対策）してファイルへダウンロード
   （`HTTPS_PROXY` が設定されていれば proxy 経由）
2. 取得したファイルが Scoop installer か（`-ScoopDir` パラメータを持つか）確認
3. `-ScoopDir %LOCALAPPDATA%\Programs\Scoop` を指定して実行（昇格しない）

という順で行い、各段階の失敗は理由と手動導入手順を表示する。winget は
「Scoop を用意できなかった場合の fallback」に限定し、Required パッケージのみ
winget id を持つ。

### PowerShell 5.1

`install.ps1` は **Windows PowerShell 5.1 と PowerShell 7 の両方**で動作する
（`#Requires -Version 5.1`、PS7 専用構文・専用自動変数・専用 cmdlet を使わない、
ファイルは ASCII のみ）。実行ポリシーでブロックされる場合:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\install.ps1
```

Linux / WSL では chezmoi を導入したうえで
`chezmoi init --apply --source <リポジトリのパス>` を実行する（将来 `install.sh` を
`install.ps1` の隣に置く場合も同じ構造）。

## テスト

[Pester](https://pester.dev/) 5 以降が必要。

```powershell
Install-Module Pester -Scope CurrentUser -MinimumVersion 5.0
Invoke-Pester -Path .\tests
```

テストは `install.ps1` を子プロセスとして実行する。`HOME` / `USERPROFILE` /
`SCOOP` は一時ディレクトリ、`PATH` は fake executable のみ、`HTTPS_PROXY` は閉じた
ポートを指すため、実際のホームディレクトリ・実際の Scoop・ネットワークには触れない。
`chezmoi` が PATH にある場合は、一時ホームへ実際に適用する end-to-end テストも
実行される（`-SkipPackages` 付き）。

Windows 実機での確認は次の順で行うとよい。

```powershell
powershell.exe -NoProfile -Command "Invoke-Pester -Path .\tests"   # 5.1 でのテスト
pwsh -NoProfile -Command "Invoke-Pester -Path .\tests"             # 7 でのテスト
.\install.ps1 -DryRun                                              # 計画の確認
.\install.ps1                                                      # 実行
scoop list; chezmoi doctor                                         # 結果の確認
```
