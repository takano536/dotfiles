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

    # パス
    $shortPath = (Get-Location).Path.Replace([Environment]::GetFolderPath('UserProfile'), '~')
    $pathElems = $shortPath -split '\\' | Where-Object { $_ -ne '' }
    if ($pathElems.Count -gt 3) { $shortPathElems = @($pathElems[0]) + '...' + $pathElems[-2..-1] } else { $shortPathElems = $pathElems }
    $path = ($shortPathElems -join ' -> ')

    # 曜日と現在時刻
    $weekday = [System.Globalization.CultureInfo]::InvariantCulture.DateTimeFormat.GetDayName((Get-Date).DayOfWeek)
    $time = (Get-Date).ToString('HH:mm')

    # シェルバージョン
    $ver = $PSVersionTable.PSVersion
    $shellVersion = "$($ver.Major).$($ver.Minor)"
    $shellText = "Posh v$shellVersion"

    # 1行目
    Write-Host ''
    Write-Host $user -ForegroundColor Blue -NoNewline
    Write-Host ' in ' -NoNewline
    Write-Host "📁 $path" -ForegroundColor DarkYellow -NoNewline
    Write-Host ' on ' -NoNewline
    Write-Host "📅 $weekday" -ForegroundColor Cyan -NoNewline
    Write-Host ' at ' -NoNewline
    Write-Host "⌚ $time" -ForegroundColor Magenta -NoNewline
    Write-Host ' via ' -NoNewline
    Write-Host "🚀 $shellText" -ForegroundColor DarkRed -NoNewline
    
    # 2行目
    Write-Host ''
    Write-Host '❯' -ForegroundColor $inputChrColor -NoNewline

    return ' '
}
