# dotfiles

[chezmoi](https://www.chezmoi.io/) で管理している dotfiles。

- `home/` … chezmoi の source state（`.chezmoiroot` でここが source directory になる）
- `install.ps1` … Windows 用のセットアップスクリプト
- `tests/` … `install.ps1` の Pester テスト

## セットアップ（Windows）

前提: [Git for Windows](https://gitforwindows.org/)。chezmoi が無い場合は Scoop
（無ければ winget）で自動インストールを試みる。管理者権限は不要。

```powershell
git clone git@github.com:takano536/dotfiles.git
cd dotfiles
.\install.ps1
```

`install.ps1` は次を行う。

1. `git` / `chezmoi` の存在確認（chezmoi が無ければ `scoop install chezmoi`、
   次に `winget install twpayne.chezmoi` を試す）
2. `chezmoi init --apply --source <リポジトリのパス>` の実行
   - `home/.chezmoi.toml.tmpl` により chezmoi の設定ファイルへ `sourceDir` が
     記録されるので、以後は `chezmoi apply` / `chezmoi diff` を素で実行できる
3. 完了メッセージの表示

何度実行しても安全（chezmoi 自体が冪等で、スクリプトは PATH や設定ファイルへ
追記を行わない）。差分の確認だけしたい場合は次のとおり。

```powershell
.\install.ps1 -DryRun
.\install.ps1 -Verbose            # chezmoi の適用内容を表示
.\install.ps1 -SkipChezmoiInstall # chezmoi が無い場合に自動インストールしない
```

`install.ps1` は **Windows PowerShell 5.1 と PowerShell 7 の両方**で動作する
（`#Requires -Version 5.1`、PS7 専用構文は使用しない、ASCII のみ）。実行ポリシーで
ブロックされる場合は次のように実行する。

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\install.ps1
```

Linux / WSL では chezmoi を導入したうえで `chezmoi init --apply --source <リポジトリのパス>`
を実行する（将来 `install.sh` を `install.ps1` の隣に置く場合も同じ構造）。

## テスト

[Pester](https://pester.dev/) 5 以降が必要。

```powershell
Install-Module Pester -Scope CurrentUser -MinimumVersion 5.0
Invoke-Pester -Path .\tests
```

テストは `install.ps1` を子プロセスとして実行し、一時ディレクトリを
`HOME` / `USERPROFILE` にした状態で検証するため、実際のホームディレクトリは
変更されない。`chezmoi` が PATH にある場合は、一時ホームへ実際に適用する
end-to-end テストも実行される。
