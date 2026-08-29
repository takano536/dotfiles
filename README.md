# dotfiles

[chezmoi](https://www.chezmoi.io/) で管理している dotfiles と、Windows 用の
bootstrap installer。

- `home/` … chezmoi の source state（`.chezmoiroot` でここが source directory になる）
- `install.ps1` … Windows 用のセットアップスクリプト
- `packages/windows.psd1` … `install.ps1` が導入するパッケージ定義
- `tests/` … installer の Pester テストと dotfiles の smoke テスト
- `.github/workflows/test.yml` … CI（Windows / Linux の 2 job）

## セットアップ（Windows）

**Requirements**

- Windows
- Windows PowerShell 5.1（OS 標準。PowerShell 7 は installer が導入する）
- このリポジトリを取得済み（clone または ZIP 展開）

Git / Scoop / chezmoi / PowerShell 7 は **事前に必要ない**（installer が導入する）。
管理者権限も不要。

**Primary/bootstrap path: Windows PowerShell 5.1**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

新しい Windows 環境には PowerShell 7 がまだ無いため、これが正式な起動経路。
PowerShell 7 からの実行も技術的には可能だが、bootstrap 経路は 5.1 とする。
installer は途中で PowerShell 7 を導入した後も 5.1 のプロセスで処理を続け、
PS7 用モジュールの導入など `pwsh.exe` が必要な処理のみ子プロセスとして呼ぶ。

**Package manager: Scoop only**

パッケージ管理は Scoop だけを使う。Windows Terminal 設定が
`%LOCALAPPDATA%\Programs\Scoop\apps\pwsh\current\pwsh.exe` や
`...\apps\git\current\bin\bash.exe` のように Scoop の install layout を直接
参照しているため、Scoop 以外から同じツールを入れても環境が一致しない。
Scoop を確保できなければ installer は失敗する（代替の package manager は無い）。

`install.ps1` の処理順:

1. リポジトリルートの解決（`.chezmoiroot` と `packages/windows.psd1` を検証）
2. 前提確認（PowerShell / OS の表示、Scoop ルートの決定）
3. Scoop の確保（無ければ公式 installer で `%LOCALAPPDATA%\Programs\Scoop` に導入。
   **失敗したらここで exit 1**。以降の package 導入も `chezmoi apply` も行わない）
4. Scoop bucket の確保（`main`、`extras`）
5. Required パッケージの導入
6. Optional パッケージの導入
7. PowerShell モジュールの導入（導入済みの `pwsh` を子プロセスとして使用）
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

`-DryRun` では、Scoop bootstrap の予定・追加予定の bucket・導入予定のパッケージ
（表示されるパッケージマネージャは Scoop のみ）・chezmoi の適用予定
（`chezmoi --dry-run`）が表示されるだけで、ネットワークアクセスも
パッケージ導入も HOME の変更も行われない。

### 冪等性

何度実行しても安全。

- パッケージは `%SCOOP%\apps\<name>\current` の有無と command の解決結果で判定し、
  導入済みなら再インストールしない（shim を作らない manifest や、shim 作成直後で
  PATH が未更新の場合も検出できる）
- bucket は `%SCOOP%\buckets\<name>` があれば再追加しない
- PATH や設定ファイルへの追記は行わない（`chezmoi apply` と Scoop に任せる）
- chezmoi 自体が冪等

### Scoop の方針

Windows のパッケージ管理は **Scoop のみ**。この dotfiles は
`$env:SCOOP` を `%LOCALAPPDATA%\Programs\Scoop` に固定し、Windows Terminal も
その下の `pwsh` / `git` の実パスを参照しているため、Scoop は必須インフラであり
代替経路を持たない。

Scoop が無い場合は公式 installer（Scoop プロジェクトの配布元
`https://get.scoop.sh`。実体は `scoopinstaller/install` の `install.ps1`）を使う。
`iex (irm ...)` は使わず、

1. TLS 1.2 を有効化（Windows PowerShell 5.1 対策）してファイルへダウンロード
   （`HTTPS_PROXY` が設定されていれば proxy 経由。installer にも `-Proxy` を渡す）
2. 取得したファイルが Scoop installer か（`-ScoopDir` パラメータを持つか）確認
3. `-ScoopDir %LOCALAPPDATA%\Programs\Scoop` を指定して実行（昇格しない）
4. 成功後は `$env:SCOOP` と shims を現在のプロセスの PATH へ反映

という順で行う。いずれかの段階で失敗した場合は、理由・想定 Scoop ディレクトリ・
「手動で Scoop を導入して再実行すればよい」ことを表示して non-zero exit する
（package 導入と `chezmoi apply` は行わない）。

### PowerShell 5.1

bootstrap 経路は Windows PowerShell 5.1（`#Requires -Version 5.1`、PS7 専用構文・
専用自動変数・専用 cmdlet を使わない、ファイルは ASCII のみ）。同じスクリプトは
PowerShell 7 でも動作するが、新規環境では 5.1 から実行する。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

起動時に `pwsh` は要求しない。PowerShell 7 は Required パッケージとして Scoop が
導入し、その後 PS7 用モジュールの導入時だけ `pwsh` を子プロセスとして呼ぶ。

Linux / WSL では chezmoi を導入したうえで
`chezmoi init --apply --source <リポジトリのパス>` を実行する（将来 `install.sh` を
`install.ps1` の隣に置く場合も同じ構造）。

## テスト

[Pester](https://pester.dev/) 5 が必要（`Install-Module Pester -Scope CurrentUser`）。

```powershell
Invoke-Pester -Path .\tests
```

- installer の挙動: `tests/Install.Tests.ps1`（fake Scoop / fake chezmoi / 一時 HOME
  で `install.ps1` を子プロセス実行）
- chezmoi の展開と apply: `tests/Dotfiles.Tests.ps1`（一時 HOME へ
  `chezmoi init --apply` して `chezmoi verify`）
- PowerShell 5.1 互換の静的チェック
- shell / config の軽量 smoke check（PowerShell・JSON・TOML の parse、`bash -n`、
  fish・tmux は導入済みの場合のみ）

設定値そのものはテストしない（色・keymap・alias・theme・パッケージ追加を変更しても
`tests/` の修正は不要）。パッケージ名は `packages/windows.psd1` から読むため、
Optional を 1 件追加してもテストは変更なしで通る。

## CI

`.github/workflows/test.yml` の 2 job のみ（`windows-latest` / `ubuntu-latest`）。

- windows: Windows PowerShell 5.1 であることを確認 → Pester（5.1 と 7 の両方）→
  PSScriptAnalyzer（Error のみ）
- linux: dotfiles の smoke test（chezmoi apply/verify と shell/config parse）

**CI does not install the full workstation package set.** Scoop bootstrap も
`scoop install`（gcc / tree-sitter / Optional packages）も PSModules の実導入も
行わない。パッケージ導入の流れは fake Scoop によるテストで検証し、実際の
package manager・ネットワーク・manifest の可用性を CI の成否条件にしない。
CI が入れるのはテスト自体に必要な Pester と chezmoi のバイナリだけ。

Windows 実機での確認は次の順で行うとよい。

```powershell
powershell.exe -NoProfile -Command "Invoke-Pester -Path .\tests"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -DryRun
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
scoop list; chezmoi doctor
```
