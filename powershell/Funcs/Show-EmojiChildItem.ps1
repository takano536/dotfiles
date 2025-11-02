function Global:Show-EmojiChildItem {
    param(
        [string]$Path = '.',
        [switch]$All,   # -a / -Force 相当（隠しファイルも）
        [switch]$LongFormat   # -l 相当（詳細表示）
    )

    function Get-SizeString($bytes) {
        if ($bytes -ge 1GB) { return "{0:N1} GB" -f ($bytes / 1GB) }
        elseif ($bytes -ge 1MB) { return "{0:N1} MB" -f ($bytes / 1MB) }
        elseif ($bytes -ge 1KB) { return "{0:N1} KB" -f ($bytes / 1KB) }
        else { return "$bytes B " }
    }

    # --- WinAPIでリンク先を取得するための型を定義 ---
    if (-not ('LinkResolver' -as [type])) {
        Add-Type -TypeDefinition @"
        using System;
        using System.IO;
        using System.Runtime.InteropServices;
        using System.Text;

        public static class LinkResolver {
            [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
            static extern uint GetFinalPathNameByHandle(IntPtr hFile, StringBuilder lpszFilePath, uint cchFilePath, uint dwFlags);

            [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
            static extern IntPtr CreateFile(string lpFileName, uint dwDesiredAccess, uint dwShareMode,
                IntPtr lpSecurityAttributes, uint dwCreationDisposition, uint dwFlagsAndAttributes, IntPtr hTemplateFile);

            [DllImport("kernel32.dll", SetLastError = true)]
            static extern bool CloseHandle(IntPtr hObject);

            const uint FILE_FLAG_BACKUP_SEMANTICS = 0x02000000;
            const uint OPEN_EXISTING = 3;

            public static string GetRealPath(string path) {
                IntPtr handle = CreateFile(path, 0, 0x7, IntPtr.Zero, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, IntPtr.Zero);
                if (handle.ToInt64() == -1) return null;

                var sb = new StringBuilder(1024);
                GetFinalPathNameByHandle(handle, sb, (uint)sb.Capacity, 0);
                CloseHandle(handle);

                string p = sb.ToString();
                if (p.StartsWith(@"\\?\"))
                    p = p.Substring(4);
                return p;
            }
        }
"@
    }

    # --- アイコン定義 ---
    $iconMap = @{
        # 基本
        'folder'     = @{ icon='📁'; color='Yellow' }
        'txt'        = @{ icon='📝'; color='White' }
        'md'         = @{ icon='📑'; color='White' }
        'json'       = @{ icon='🧩'; color='Green' }
        'yml'        = @{ icon='🪶'; color='DarkYellow' }
        'yaml'       = @{ icon='🪶'; color='DarkYellow' }
        'xml'        = @{ icon='📄'; color='White' }
        'log'        = @{ icon='📃'; color='White' }
        'fileLink'   = @{ icon='🔗'; color='White' }
        'folderLink' = @{ icon='🗂️'; color='Yellow' }

    
        # 画像・動画・音声
        'png'    = @{ icon='🖼️'; color='Cyan' }
        'jpg'    = @{ icon='📸'; color='White' }
        'jpeg'   = @{ icon='📸'; color='White' }
        'gif'    = @{ icon='🎞️'; color='Cyan' }
        'bmp'    = @{ icon='🖼️'; color='Cyan' }
        'svg'    = @{ icon='🖋️'; color='DarkMagenta' }
        'mp4'    = @{ icon='🎬'; color='Magenta' }
        'mp3'    = @{ icon='🎵'; color='Magenta' }
        'wav'    = @{ icon='🔊'; color='Gray' }
        'flac'   = @{ icon='🎶'; color='Magenta' }
    
        # コード系
        'ps1'    = @{ icon='⚡'; color='Cyan' }
        'psm1'   = @{ icon='⚡'; color='Cyan' }
        'bat'    = @{ icon='⚡'; color='Yellow' }
        'cmd'    = @{ icon='⚡'; color='Yellow' }
        'cpp'    = @{ icon='💠'; color='White' }
        'c'      = @{ icon='💠'; color='White' }
        'h'      = @{ icon='📄'; color='White' }
        'hpp'    = @{ icon='📄'; color='White' }
        'py'     = @{ icon='🐍'; color='Green' }
        'js'     = @{ icon='🟨'; color='DarkYellow' }
        'ts'     = @{ icon='🔷'; color='Cyan' }
        'rs'     = @{ icon='🦀'; color='DarkRed' }
        'html'   = @{ icon='🌐'; color='Cyan' }
        'css'    = @{ icon='🎨'; color='Red' }
        'scss'   = @{ icon='🎨'; color='Red' }
        'java'   = @{ icon='☕'; color='Red' }
        'cs'     = @{ icon='🧱'; color='Cyan' }
        'go'     = @{ icon='💎'; color='Cyan' }
        'sh'     = @{ icon='🐚'; color='DarkGreen' }
    
        # 実行・バイナリ
        'exe'    = @{ icon='💾'; color='White' }
        'dll'    = @{ icon='⚙️'; color='White' }
        'bin'    = @{ icon='📦'; color='DarkYellow' }
        'msi'    = @{ icon='📦'; color='DarkYellow' }
    
        # 圧縮ファイル
        'zip'    = @{ icon='📦'; color='DarkYellow' }
        '7z'     = @{ icon='📦'; color='DarkYellow' }
        'tar'    = @{ icon='📦'; color='DarkYellow' }
        'gz'     = @{ icon='📦'; color='DarkYellow' }
    
        # データ・スプレッドシート
        'csv'    = @{ icon='📊'; color='Cyan' }
        'ods'    = @{ icon='📗'; color='Green' }
    
        # Officeファイル
        'docx'   = @{ icon='📘'; color='Blue' }
        'doc'    = @{ icon='📘'; color='Blue' }
        'pptx'   = @{ icon='📙'; color='Red' }
        'ppt'    = @{ icon='📙'; color='Red' }
        'xlsx'   = @{ icon='📗'; color='Green' }
        'xls'    = @{ icon='📗'; color='Green' }
        'vsdx'   = @{ icon='📐'; color='White' }
        'pub'    = @{ icon='📰'; color='White' }
    
        # PDF・ドキュメント
        'pdf'    = @{ icon='📕'; color='DarkRed' }
        'rtf'    = @{ icon='📕'; color='DarkRed' }
    
        # 設定・構成ファイル
        'ini'    = @{ icon='⚙️'; color='White' }
        'conf'   = @{ icon='⚙️'; color='White' }
        'config' = @{ icon='⚙️'; color='White' }
        'env'    = @{ icon='🌱'; color='Green' }
        'reg'    = @{ icon='⚙️'; color='White' }
    
        # バージョン管理・プロジェクト
        'gitignore'     = @{ icon='🚫'; color='DarkRed' }
        'gitattributes' = @{ icon='📜'; color='DarkYellow' }
        'toml'          = @{ icon='📜'; color='DarkYellow' }
        'lock'          = @{ icon='🔒'; color='Yellow' }
        'sln'           = @{ icon='🧩'; color='Green' }
        'csproj'        = @{ icon='🧩'; color='Green' }
        'vcxproj'       = @{ icon='🧩'; color='Green' }
    
        # その他
        'bak' = @{ icon='🛡️'; color='Blue' }
        'tmp' = @{ icon='⏳'; color='White' }
        'lnk' = @{ icon='🔗'; color='Cyan' }
        'url' = @{ icon='🌍'; color='Cyan' }
    }

    # パラメータ設定
    $params = @{ LiteralPath = $Path; ErrorAction = 'SilentlyContinue' }
    if ($All) { $params['Force'] = $true }

    $items = Microsoft.PowerShell.Management\Get-ChildItem @params | Sort-Object Name

    # LongFormat (-l) の場合のみ詳細出力
    if ($LongFormat) {
        Write-Host ('{0,-11} {1,20} {2,12} {3}' -f 'Mode', 'LastWriteTime', 'Length', 'Name') -ForegroundColor DarkGray
        Write-Host ('{0,-11} {1,20} {2,12} {3}' -f '----', '-------------', '------', '----') -ForegroundColor DarkGray
    }

    # 各アイテムの装飾済み文字列を作る
    $entries = @()
    foreach ($item in $items) {
        $isLink = $false
        $targetPath = $null

        # --- リンク判定 --- 
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            $isLink = $true
            $targetPath = [LinkResolver]::GetRealPath($item.FullName) 
        }

        if ($isLink) {
            $meta = if ($item.PSIsContainer) { $iconMap['folderLink'] } else { $iconMap['fileLink'] } 
        } elseif ($item.PSIsContainer) {
            $meta = $iconMap['folder']
        } else {
            $ext = $item.Extension.TrimStart('.').ToLower()
            $meta = if ($iconMap.ContainsKey($ext)) { $iconMap[$ext] } else { @{ icon='📄'; color='Gray' } }
        }

        $icon  = $meta.icon
        $color = $meta.color
        $name  = "$icon $($item.Name)"

        if ($isLink -and $targetPath) {
            $name += " → $targetPath"
        }

        $entries += [PSCustomObject]@{
            Mode = $item.Mode
            Time = $item.LastWriteTime.ToString('yyyy/MM/dd HH:mm')
            Size = if (-not $item.PSIsContainer) { Get-SizeString $item.Length } else { "" }
            Text = $name
            Color = $color
        }
    }

    if ($LongFormat) {
        foreach ($e in $entries) {
            $prefix = '{0,-11} {1,20} {2,12:N0} ' -f $e.Mode, $e.Time, $e.Size
            Write-Host -NoNewline $prefix -ForegroundColor DarkGray
            Write-Host $e.Text -ForegroundColor $e.Color
        }
    } else {
        # --- 横並びカラム表示 ---
        $maxWidth = [Console]::WindowWidth - 2
        $maxLen = ($entries | ForEach-Object {($_.Text).Length} | Measure-Object -Maximum).Maximum
        $colWidth = [Math]::Min([Math]::Max($maxLen + 4, 15), $maxWidth)
        $cols = [Math]::Max([Math]::Floor($maxWidth / $colWidth), 1)

        $i = 0
        foreach ($e in $entries) {
            $padded = $e.Text.PadRight($colWidth)
            Write-Host -NoNewline $padded -ForegroundColor $e.Color
            $i++
            if ($i -ge $cols) {
                Write-Host ''
                $i = 0
            }
        }
        if ($i -ne 0) { Write-Host '' }
    }
}

Set-Alias -Scope Global -Option AllScope -Name ls -Value Show-EmojiChildItem
function Global:la { param($Path = '.') Show-EmojiChildItem -Path $Path -All }
function Global:ll { param($Path = '.') Show-EmojiChildItem -Path $Path -All -LongFormat}