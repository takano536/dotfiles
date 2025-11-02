# --- 初回のみキャッシュ構築 ---
if (-not $global:_PromptCache) {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($id)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    $global:_PromptCache = @{
        User      = if ($isAdmin) { 'Admin' } else { [Environment]::UserName }
        ShellText = "Posh v$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)"
        Home      = [Environment]::GetFolderPath('UserProfile')
    }
}

# --- 超軽量 Git ブランチ関数 (.git/HEAD 読み取り) ---
function Global:Get-GitBranch {
    param($Path)

    $p = $Path
    while ($p -and -not (Test-Path "$p\.git")) { $p = Split-Path $p }
    if (-not $p) { return $null }

    $headPath = "$p\.git\HEAD"
    if (-not (Test-Path $headPath)) { return $null }

    $head = Get-Content $headPath -ErrorAction SilentlyContinue
    if ($head -match 'ref: refs/heads/(.+)$') {
         $Matches[1]
    } else {
        return $head.Substring(0, 7)
    }
}

# --- プロンプト本体 ---
function Global:prompt {
    $success = $?
    $cwd = (Get-Location).Path
    $shortPath = $cwd.Replace($global:_PromptCache.Home, '~')

    # 長すぎるパスを短縮
    $pathElems = $shortPath -split '\\' | Where-Object { $_ -ne '' }
    if ($pathElems.Count -gt 3) { $shortPath = "...\$($pathElems[-2])\$($pathElems[-1])" }
    $shortPath = $shortPath.Replace('\', ' » ')

    # Git ブランチ (超軽量)
    $branch = Get-GitBranch $cwd
    $branchText = if ($branch) { "🌱 $branch" } else { "" }

    # 日時
    $time = (Get-Date).ToString('HH:mm')

    # --- 描画 ---
    Write-Host ""  # 改行
    Write-Host -NoNewline -ForegroundColor Blue $global:_PromptCache.User
    Write-Host -NoNewline ' in '
    Write-Host -NoNewline -ForegroundColor Yellow "📁 $shortPath"
    if ($branch) {
        Write-Host -NoNewline ' on '
        Write-Host -NoNewline -ForegroundColor Cyan $branchText
    }
    Write-Host -NoNewline ' via '
    Write-Host -NoNewline -ForegroundColor Red "🚀 $($global:_PromptCache.ShellText)"
    Write-Host -NoNewline ' at '
    Write-Host -NoNewline -ForegroundColor Magenta "⌚ $time"
    Write-Host ''

    # 成功/失敗色付きプロンプト
    $promptColor = if ($success) { 'Green' } else { 'Red' }
    Write-Host -NoNewline -ForegroundColor $promptColor '❯'
    return ' '
}