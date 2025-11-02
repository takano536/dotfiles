$global:Z_DATA_FILE = "$env:XDG_CACHE_HOME\z\.zhistory"
$global:Z_MAX_ENTRIES = 300

# 履歴を読み込む
function Global:Load-ZData {
    if (-not (Test-Path $Z_DATA_FILE)) { return @() }
    $result = @()
    foreach ($line in Get-Content $Z_DATA_FILE) {
        if ($line -notmatch '^(?<path>.+?)\|(?<score>\d+)\|(?<time>\d+)$') { continue }
        $result += [PSCustomObject]@{
            Path  = $matches.path
            Score = [int]$matches.score
            Time  = [int64]$matches.time
        }
    }
    return $result
}

# 履歴を保存する
function Global:Save-ZData($data) {
    if (-not $data) { return }
    $dir = Split-Path $Z_DATA_FILE -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }

    $lines = foreach ($e in ($data | Sort-Object Score -Descending | Select-Object -First $Z_MAX_ENTRIES)) {
        "$($e.Path)|$($e.Score)|$($e.Time)"
    }
    if ($lines) { $lines | Set-Content -Encoding UTF8 $Z_DATA_FILE }
}

# 履歴を更新する
function Global:Update-Z {
    $cwd = (Get-Location).Path
    $data = @(Load-ZData)
    $now = [DateTimeOffset]::Now.ToUnixTimeSeconds()

    $entry = $data | Where-Object { $_.Path -eq $cwd }
    if ($entry) {
        $entry.Score++
        $entry.Time = $now
    } else {
        $new = [PSCustomObject]@{ Path = $cwd; Score = 1; Time = $now }
        $data = @($data + $new)
    }

    Save-ZData $data
}

# cd フック（安全版）
function Global:Set-Location {
    param([string]$path)
    if (-not $path) {
        Microsoft.PowerShell.Management\Set-Location
        return
    }
    Microsoft.PowerShell.Management\Set-Location $path
    Update-Z
}

# z コマンド本体
function Global:Invoke-ZJump {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$query)

    $data = Load-ZData
    if (-not $data) { Write-Host "No history yet."; return }

    # 引数なし → 履歴表示
    if (-not $query) {
        $data | Sort-Object Score -Descending |
            Select-Object -First 20 |
            Format-Table @{Label='Count';Expression={$_.Score}}, Path
        return
    }

    # 検索
    $pattern = ($query -join '*')
    $matches = $data | Where-Object { $_.Path -like "*$pattern*" } | Sort-Object Score -Descending
    if (-not $matches) { Write-Host "No match for '$($query -join ' ')'" ; return }

    $dest = $matches[0].Path
    if (Test-Path $dest) {
        Microsoft.PowerShell.Management\Set-Location $dest
        Update-Z
        return
    }

    Write-Host "Path not found: $dest"
    $newData = $data | Where-Object { $_.Path -ne $dest }
    Save-ZData $newData
}

# Tab 補完: z <TAB> で履歴パス候補を出す
Register-ArgumentCompleter -CommandName z -ScriptBlock {
    param($wordToComplete)

    $dataFile = "$env:XDG_CONFIG_HOME\z\.zhistory"
    if (-not (Test-Path $dataFile)) { return }

    $paths = @()
    foreach ($line in Get-Content $dataFile) {
        if ($line -notmatch '^(?<path>.+?)\|') { continue }
        $paths += $matches.path
    }
    if (-not $paths) { return }

    $filtered = $paths | Where-Object { $_ -like "*$wordToComplete*" } | Sort-Object -Unique
    if (-not $filtered) { return }

    foreach ($p in $filtered) {
        $leaf = Split-Path $p -Leaf
        [System.Management.Automation.CompletionResult]::new($p, $leaf, 'ParameterValue', $p)
    }
}

Set-Alias -Scope Global -Name z -Value Invoke-ZJump