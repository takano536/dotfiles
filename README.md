# dotfiles

[chezmoi](https://www.chezmoi.io/) で管理している dotfiles と、Windows / Linux 用の
bootstrap installer。

- `home/` … chezmoi の source state（`.chezmoiroot` でここが source directory になる）
- `install.ps1` … Windows 用のセットアップスクリプト
- `install.sh` … Linux（Debian 13）用のセットアップスクリプト
- `packages/windows.psd1` … `install.ps1` が導入するパッケージ定義
- `packages/linux.tsv` … `install.sh` が導入するパッケージ定義
- `tests/` … installer のテスト（Windows: Pester / Linux: bash）と dotfiles の smoke テスト
- `.github/workflows/test.yml` … CI（windows / linux / debian の 3 job）

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

Linux は下の「セットアップ（Linux / Debian 13）」を参照（`install.sh` が同じ構造で
`chezmoi init --apply --source <リポジトリのパス>` まで行う）。

## セットアップ（Linux / Debian 13）

**Requirements**

- Debian GNU/Linux 13 (trixie)。`/etc/os-release` の `ID=debian` かつ
  `VERSION_ID=13` を正式サポート条件とする。それ以外では理由を表示して
  non-zero exit し、apt 前提の処理へ進まない（Ubuntu などへの汎用化はしない）
- bash（Debian 標準）
- 通常ユーザー（root ではない。`sudo ./install.sh` や root shell からの実行は拒否する）。
  このリポジトリを clone または展開済み

git / chezmoi は **事前に必要ない**（installer が導入する）。

**Primary/bootstrap path: bash**

```bash
bash ./install.sh
```

`install.sh` の処理順:

1. オプション解析（未知オプションは non-zero exit）
2. root 実行の拒否（`EUID == 0` なら理由を表示して exit 1）
3. リポジトリルートの解決（script 自身の位置から。`.chezmoiroot` と
   `packages/linux.tsv` を検証。cwd に依存しない）
4. ディストリビューション判定（`/etc/os-release`）
5. package 定義の読み込みと検証
6. Required パッケージの導入（`apt-get`）
7. Optional パッケージの導入（`apt-get`）
8. Required に失敗があればここで exit 1（`chezmoi apply` は行わない）
9. chezmoi の確保（無ければ公式 release binary を `~/.local/bin` へ）
10. `chezmoi init --apply --source <リポジトリのパス>`
11. サマリ表示（present / installed / planned / optional failures / notes）

**Package manager: apt only**

system package は `apt-get` だけを使う。Homebrew / Linuxbrew / snap / flatpak /
nix / pacman / dnf / yum は使わず、複数 package manager の fallback も作らない。
第三者 apt repository の追加も行わない（`/etc/apt` は触らない）。
`apt` CLI ではなく automation 向けの `apt-get` を使い、`DEBIAN_FRONTEND=noninteractive`
で対話プロンプトを避け、`apt-get update` は 1 run につき最大 1 回、install は
Required / Optional ごとに batch 実行する（batch が失敗した場合のみ、どれが
失敗したかを特定するため 1 つずつ retry する）。

**sudo は apt 操作時のみ**

`sudo ./install.sh` は使わない。root で起動した場合は起動直後に

```text
install.sh: do not run install.sh as root or with sudo. ...
```

と表示して exit 1 する（root の HOME へ chezmoi が書き込んだり、root 所有の
ファイルが残るのを防ぐため）。apt 操作だけを
`sudo env DEBIAN_FRONTEND=noninteractive apt-get ...` として実行し、
`chezmoi apply` は必ず実行ユーザーとして走る。導入すべき package があるのに
sudo が無い場合は明確なエラーになる（全て導入済みなら sudo は不要）。

### インストール対象

パッケージ一覧は `packages/linux.tsv`（tab 区切りのプレーンデータ。shell として
source はしない）が唯一の定義元。`install.sh` にパッケージ名は書かない。列は
`tier` / `source` / `package` / `command` / `why`。

- `tier` … `required` / `optional`
- `source` … `apt`（Debian 13 の package）/ `upstream`（Debian 13 に無いので公式
  release から取得）/ `none`（Debian 13 に無く、bootstrap もしない）
- `command` … Debian が実際に提供する実行ファイル名。package 名と一致しないものが
  ある（`fd-find` → `fdfind`、`bat` → `batcat`、`git-delta` → `delta`、
  `tree-sitter-cli` → `tree-sitter`）。この dotfiles は `fd` / `bat` を参照して
  いないため、互換 symlink や alias の層は作らない

**Required** … 適用した dotfiles が壊れる/既定動作に落ちるもの。導入に失敗したら
installer 全体を失敗（exit 1）扱いにし、`chezmoi apply` を行わない。

| package | command | 理由 |
|---|---|---|
| `git` | `git` | chezmoi の source 更新、`.config/git/config` |
| `curl` | `curl` | Debian 13 に無い chezmoi の取得 |
| `ca-certificates` | `update-ca-certificates` | その取得と git の HTTPS |
| `bash` | `bash` | `.bashrc` / `.bash_profile`、installer 自体 |
| `fish` | `fish` | `.config/fish`（Linux 側の対話シェル設定） |
| `tmux` | `tmux` | `.config/tmux/tmux.conf` |
| `neovim` | `nvim` | bash / fish の `vi` `vim` alias、`.config/nvim` |
| `starship` | `starship` | bash / fish の prompt 初期化、`.config/starship` |
| `chezmoi` | `chezmoi` | このリポジトリの適用 |

Windows 版の分類をそのまま移植していない。Linux では `.chezmoiignore` により
fish / tmux 設定が適用されるため、`fish` と `tmux` を Required に含めている。

**Optional** … 日常的に使う CLI / TUI と Neovim 用の補助ツール。失敗しても続行し、
最後のサマリに失敗パッケージを表示する（installer 自体は成功扱い）。

`zoxide` `eza` `fzf` `tree-sitter-cli` `gcc` `ripgrep` `fd-find` `bat` `jq`
`git-delta` `lazygit` `gh` `btop` `fastfetch` `yazi`

**apt 以外から入れるもの**

- `chezmoi` … Debian 13 の repository に package が無い。bootstrap 自体に必要な
  ため、公式 upstream（`github.com/twpayne/chezmoi` の release）から取得する。
  `curl | sh` は使わず、HTTPS のみ・`mktemp -d` の一時ディレクトリへ
  download → 公式 `checksums.txt` と `sha256sum` で検証 → `~/.local/bin` へ配置、
  という順で行う（`/usr/local` などシステム領域は汚さない）。architecture は
  `uname -m` から判定し、対応しない場合は手動導入を案内して終了する。
  version は再現性のため pin してある
- `yazi` … Debian 13 に package が無いため bootstrap しない（`source` が `none`）。
  既に PATH にあれば present として扱い、無ければ skip した旨を表示するだけ

`~/.local/bin` は fish の `conf.d/20-path.fish` と bash の `.config/bash/env.bash`
が PATH に追加する。

### インストールしないもの

Windows 版と同じ方針。**AI coding agent（Oh My Pi / `omp`、Claude Code、Codex CLI）
は入らない。** そのほか Bun / Node.js / Python などのランタイム、Docker などの
container runtime、GUI アプリ、フォント、SSH 鍵や認証情報も対象外。既に環境に
あっても削除はしない（単に installer が導入しないだけ）。

### オプション

```bash
bash ./install.sh --dry-run               # 計画のみ表示。install / download / HOME 変更を一切行わない
bash ./install.sh --skip-packages         # chezmoi 以外の package 導入を行わない
bash ./install.sh --skip-optional         # Required だけ入れ、CLI / TUI は入れない
bash ./install.sh --skip-chezmoi-install  # chezmoi が無い場合に自動導入せずエラー終了
bash ./install.sh --help                  # 使い方
```

未知のオプションは non-zero exit する。`--dry-run` では `apt-get update` /
`apt-get install` / download / file write / symlink 作成 / `chezmoi apply` を
一切実行せず、実行予定のコマンドを `would run:` として表示するだけ。

### 冪等性

2 回目以降の実行も安全。

- package は `command -v <command>`、解決できない場合は `dpkg-query` で判定し、
  導入済みなら `apt-get` を呼ばない（`ca-certificates` のように通常ユーザーの PATH に
  コマンドが出ないものがあるため両方見る）
- 導入すべきものが無ければ `apt-get update` すら実行しない
- `~/.bashrc` などへの行の追記は行わない（設定適用は chezmoi に任せる）
- chezmoi 自体が冪等

## テスト

**Windows / dotfiles**: [Pester](https://pester.dev/) 5 が必要
（`Install-Module Pester -Scope CurrentUser`）。

```powershell
Invoke-Pester -Path .\tests
```

- installer の挙動: `tests/Install.Tests.ps1`（fake Scoop / fake chezmoi / 一時 HOME
  で `install.ps1` を子プロセス実行）
- chezmoi の展開と apply: `tests/Dotfiles.Tests.ps1`（一時 HOME へ
  `chezmoi init --apply` して `chezmoi verify`。OS ごとの `.chezmoiignore` の分岐も
  確認する）
- PowerShell 5.1 互換の静的チェック
- shell / config の軽量 smoke check（PowerShell・JSON・TOML の parse、`bash -n`、
  fish・tmux は導入済みの場合のみ）

**Linux installer**: 追加の依存は無い（plain bash。Bats などは使わない）。

```bash
bash ./tests/install.tests.sh
```

`install.sh` を、PATH に fake `apt-get` / `sudo` / `dpkg-query` / `curl` /
`chezmoi` と最小限の coreutils だけを置いた子プロセスとして、一時 HOME と注入した
os-release で実行する（実 apt・実 HOME・ネットワークには一切触れない）。確認する
contract は syntax、package 定義の schema、`--dry-run` / `--skip-*` の挙動、
root 実行の拒否、package 定義ファイルの不在、非対応ディストリビューション、
`apt-get` や `sudo` の不在、Required / Optional の失敗時の扱い、chezmoi の
exit code、冪等性、chezmoi の upstream 取得。`shellcheck` があれば
`--severity=warning` で実行し、無ければ skip する。root 実行の拒否は uid 0 が
必要なため、非 root かつ user namespace が使えない環境では skip され、CI の
debian job（container の既定 user が root）が実経路を確認する。

設定値そのものはテストしない（色・keymap・alias・theme・パッケージ追加を変更しても
`tests/` の修正は不要）。パッケージ名は `packages/windows.psd1` /
`packages/linux.tsv` から読むため、Optional を 1 件追加してもテストは変更なしで通る。

## CI

`.github/workflows/test.yml` の 3 job のみ。

- windows（`windows-latest`）: Windows PowerShell 5.1 であることを確認 →
  Pester（5.1 と 7 の両方）→ PSScriptAnalyzer（Error のみ）
- linux（`ubuntu-latest`）: `bash -n install.sh` → ShellCheck（warning 以上。
  runner に同梱）→ Linux installer test → dotfiles の smoke test
  （chezmoi apply/verify と shell/config parse）
- debian（`ubuntu-latest` + `container: debian:13`）: 実 Debian 13 userland で
  `bash -n install.sh` → root 実行が拒否されることを確認（container の既定は root）
  → 非 root ユーザーを作成し、その user で Linux installer test と
  `install.sh --dry-run`

**CI does not install the full workstation package set.** Scoop bootstrap も
`scoop install` も PSModules の実導入も行わず、Linux 側も
`apt-get install <全 package>` や実機への `chezmoi apply` を行わない。
パッケージ導入の流れは fake package manager によるテストで検証し、実際の
package manager・ネットワーク・package の可用性を CI の成否条件にしない。
CI が入れるのはテスト自体に必要な Pester と chezmoi のバイナリだけで、Linux
installer test 自体は追加 package を必要としない。

Windows 実機での確認は次の順で行うとよい。

```powershell
powershell.exe -NoProfile -Command "Invoke-Pester -Path .\tests"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -DryRun
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
scoop list; chezmoi doctor
```

Debian 13 実機での確認は次の順で行うとよい（`--dry-run` までは環境を変更しない）。

```bash
bash ./tests/install.tests.sh
bash ./install.sh --dry-run
bash ./install.sh
chezmoi doctor
```
