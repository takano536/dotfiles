##### Starship #####
$error.clear()
Get-Command -All starship -ErrorAction SilentlyContinue | Out-Null
if (!$error) { Invoke-Expression (& starship init powershell); return }

### StarShipがインストールされていない場合は自前でプロンプトを作成 ###
function Global:prompt {

    # 前回のコマンドの実行結果を取得
    if ($?) { $inputChrColor = 'Green' } else { $inputChrColor = 'Red' }

    # ユーザー名と管理者チェック
    $user = [Environment]::UserName
    $isAdmin = (
        New-Object Security.Principal.WindowsPrincipal(
            [Security.Principal.WindowsIdentity]::GetCurrent()
        )
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($isAdmin) { $user = 'Admin' }

    # カレントディレクトリ ホームなら~に置き換え
    $path = (Get-Location)
    $shortPath = $path.Path.Replace([Environment]::GetFolderPath('UserProfile'), '~')

    # 現在時刻
    $time = (Get-Date).ToString('HH:mm')

    # 1行目
    Write-Host ''
    Write-Host $user -ForegroundColor Cyan -NoNewline
    Write-Host ' in ' -NoNewline
    Write-Host $shortPath -ForegroundColor DarkYellow -NoNewline
    Write-Host ' at ' -NoNewline
    Write-Host $time -ForegroundColor Magenta -NoNewline
    
    # 2行目
    Write-Host ''
    Write-Host '❯' -ForegroundColor $inputChrColor -NoNewline

    return ' '
}
