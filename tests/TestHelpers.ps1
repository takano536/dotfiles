<#
    Helpers for Install.Tests.ps1.

    Dot-sourced both at discovery time (for -Skip conditions) and inside
    BeforeAll (Pester runs tests in a scope that does not see functions defined
    during discovery).
#>

#Requires -Version 5.1

$RepoRoot = Split-Path -Parent $PSScriptRoot
$OnWindows = ($env:OS -eq 'Windows_NT')

$PowerShellExe = Join-Path $PSHOME $(
    if ($PSVersionTable.PSEdition -eq 'Core') {
        if ($OnWindows) { 'pwsh.exe' } else { 'pwsh' }
    }
    else {
        'powershell.exe'
    }
)

function Find-RealExecutable {
    <#
        Resolved at dot-source time so that -Skip conditions can use it during
        Pester discovery. Tools that are missing are skipped, never installed.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name
    )

    return Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty Source
}

$RealChezmoi = Find-RealExecutable 'chezmoi'
$RealGit = Find-RealExecutable 'git'
$RealBash = Find-RealExecutable 'bash'
$RealFish = Find-RealExecutable 'fish'
$RealTmux = Find-RealExecutable 'tmux'

function New-Sandbox {
    <#
        Creates an isolated copy of the installable part of the repository plus
        a fake HOME, a directory for fake executables and a downloaded copy of
        install.ps1 that has no repository around it. The repository copy
        deliberately contains a space so that path quoting stays covered.
    #>
    param(
        [string]$RepoDirectoryName = 'dot files'
    )

    $root = Join-Path ([IO.Path]::GetTempPath()) ('install-tests-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    $repo = Join-Path $root $RepoDirectoryName
    $sandboxHome = Join-Path $root 'home'
    $bin = Join-Path $root 'bin'
    $elsewhere = Join-Path $root 'elsewhere'
    $scoop = Join-Path $root 'scoop'
    # Where a downloaded installer sits, and what Scoop hands out on demand.
    $downloaded = Join-Path $root 'downloaded'
    $provides = Join-Path $root 'provides'
    foreach ($directory in @($repo, $sandboxHome, $bin, $elsewhere, $scoop, $downloaded, $provides)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    Copy-Item -LiteralPath (Join-Path $RepoRoot 'install.ps1') -Destination $repo
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'install.ps1') -Destination $downloaded
    Copy-Item -LiteralPath (Join-Path $RepoRoot '.chezmoiroot') -Destination $repo
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'home') -Destination $repo -Recurse
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'packages') -Destination $repo -Recurse

    return [pscustomobject]@{
        Root        = $root
        Repo        = $repo
        Script      = Join-Path $repo 'install.ps1'
        Standalone  = Join-Path $downloaded 'install.ps1'
        Home        = $sandboxHome
        Bin         = $bin
        Elsewhere   = $elsewhere
        Scoop       = $scoop
        Provides    = $provides
        # Where a bootstrap run clones to: chezmoi's default source directory
        # inside the sandbox home.
        CloneTarget = Join-Path (Join-Path (Join-Path $sandboxHome '.local') 'share') 'chezmoi'
    }
}

function Remove-Sandbox {
    param(
        [Parameter(Mandatory)]
        $Sandbox
    )

    Remove-Item -LiteralPath $Sandbox.Root -Recurse -Force -ErrorAction SilentlyContinue
}

function New-FakeExecutable {
    <#
        Writes a fake executable that appends its arguments to a log file and
        exits with the requested code, so the tests observe the real process
        boundary instead of mocking PowerShell internals.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Directory,

        [Parameter(Mandatory)]
        [string]$Name,

        [int]$ExitCode = 0
    )

    $log = Join-Path $Directory "$Name.log"

    if ($env:OS -eq 'Windows_NT') {
        $path = Join-Path $Directory "$Name.cmd"
        $lines = @(
            '@echo off'
            ">>`"$log`" echo %*"
            "exit /b $ExitCode"
        )
    }
    else {
        $path = Join-Path $Directory $Name
        $lines = @(
            '#!/bin/sh'
            "printf '%s\n' `"`$*`" >>'$log'"
            "exit $ExitCode"
        )
    }

    Set-Content -LiteralPath $path -Value $lines -Encoding ASCII
    if ($env:OS -ne 'Windows_NT') {
        & chmod '+x' $path
    }

    return $log
}

function Get-FakeInvocation {
    <#
        Returns one array element per invocation of a fake executable.
        -NoEnumerate keeps a single invocation an array.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$LogPath
    )

    $lines = @()
    if (Test-Path -LiteralPath $LogPath) {
        $lines = @(Get-Content -LiteralPath $LogPath | Where-Object { $_ -ne '' })
    }

    Write-Output $lines -NoEnumerate
}

function New-FakeScoop {
    <#
        Writes a fake scoop that logs its arguments and mimics the state that
        the installer inspects: 'install <name>' creates
        <ScoopRoot>\apps\<name>\current and 'bucket add <name>' creates
        <ScoopRoot>\buckets\<name>. With -FailPattern, invocations whose
        arguments contain that text exit 1. With -ProvideFrom, 'install <name>'
        also copies a fake <name> prepared in that directory into the shims, so
        that a package this fake installs really becomes callable.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Directory,

        [Parameter(Mandatory)]
        [string]$ScoopRoot,

        [string]$FailPattern,

        [string]$ProvideFrom
    )

    $log = Join-Path $Directory 'scoop.log'
    $shims = Join-Path $ScoopRoot 'shims'

    if ($env:OS -eq 'Windows_NT') {
        $path = Join-Path $Directory 'scoop.cmd'
        $lines = @(
            '@echo off'
            ">>`"$log`" echo %*"
        )
        if ($FailPattern) {
            $lines += "echo %* | findstr /C:`"$FailPattern`" >nul && exit /b 1"
        }
        $lines += @(
            "if `"%1`" == `"install`" mkdir `"$ScoopRoot\apps\%2\current`" 2>nul"
            "if `"%1`" == `"bucket`" if `"%2`" == `"add`" mkdir `"$ScoopRoot\buckets\%3`" 2>nul"
        )
        if ($ProvideFrom) {
            $lines += @(
                "if not `"%1`" == `"install`" goto :done"
                "mkdir `"$shims`" 2>nul"
                "if exist `"$ProvideFrom\%2.cmd`" copy /y `"$ProvideFrom\%2.cmd`" `"$shims\%2.cmd`" >nul"
                ':done'
            )
        }
        $lines += 'exit /b 0'
    }
    else {
        $path = Join-Path $Directory 'scoop'
        $lines = @(
            '#!/bin/sh'
            "printf '%s\n' `"`$*`" >>'$log'"
        )
        if ($FailPattern) {
            $lines += "case `"`$*`" in *$FailPattern*) exit 1;; esac"
        }
        # The child PATH only contains the fake executables, so the coreutils
        # need their absolute paths.
        $lines += @(
            "if [ `"`$1`" = install ]; then /bin/mkdir -p '$ScoopRoot/apps/'`"`$2`"'/current'; fi"
            "if [ `"`$1`" = bucket ] && [ `"`$2`" = add ]; then /bin/mkdir -p '$ScoopRoot/buckets/'`"`$3`"; fi"
        )
        if ($ProvideFrom) {
            $lines += @(
                "if [ `"`$1`" = install ] && [ -f '$ProvideFrom/'`"`$2`" ]; then"
                "    /bin/mkdir -p '$shims'"
                "    /bin/cp '$ProvideFrom/'`"`$2`" '$shims/'`"`$2`""
                'fi'
            )
        }
        $lines += 'exit 0'
    }

    Set-Content -LiteralPath $path -Value $lines -Encoding ASCII
    if ($env:OS -ne 'Windows_NT') {
        & chmod '+x' $path
    }

    return $log
}

function New-FakeGit {
    <#
        Writes a fake git that logs its arguments and answers the commands the
        bootstrap uses: 'clone' copies -SourceRepo instead of reaching GitHub,
        and the questions about an existing checkout are answered from -Origin
        and -Dirty. With -FailClone the clone fails like a git that cannot reach
        the remote.

        The logic lives in a PowerShell script so that one implementation serves
        both platforms; the executable on PATH is a thin launcher that logs the
        call, which is what the tests assert on.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Directory,

        [Parameter(Mandatory)]
        [string]$SourceRepo,

        [string]$Origin = 'https://github.com/takano536/dotfiles.git',

        [switch]$Dirty,

        [switch]$FailClone
    )

    $log = Join-Path $Directory 'git.log'
    $worker = Join-Path $Directory 'fake-git.ps1'

    $body = @(
        "Set-StrictMode -Version Latest"
        "`$ErrorActionPreference = 'Stop'"
        "`$source = '$SourceRepo'"
        "`$origin = '$Origin'"
        "`$dirty = `$$([bool]$Dirty)"
        "`$failClone = `$$([bool]$FailClone)"
        '$call = @($args)'
        '$directory = $null'
        "if (`$call.Count -ge 2 -and `$call[0] -eq '-C') {"
        '    $directory = $call[1]'
        '    $call = @($call[2..($call.Count - 1)])'
        '}'
        'switch ($call[0]) {'
        "    'clone' {"
        '        if ($failClone) {'
        "            [Console]::Error.WriteLine('fatal: simulated clone failure')"
        '            exit 128'
        '        }'
        '        $target = $call[-1]'
        "        New-Item -ItemType Directory -Force -Path (Join-Path `$target '.git') | Out-Null"
        '        Get-ChildItem -LiteralPath $source -Force |'
        '            Copy-Item -Destination $target -Recurse -Force'
        '        exit 0'
        '    }'
        "    'rev-parse' {"
        "        if (`$directory -and (Test-Path -LiteralPath (Join-Path `$directory '.git'))) {"
        "            Write-Output (Join-Path `$directory '.git')"
        '            exit 0'
        '        }'
        '        exit 128'
        '    }'
        "    'remote' {"
        '        Write-Output $origin'
        '        exit 0'
        '    }'
        "    'status' {"
        "        if (`$dirty) { Write-Output ' M home/dot_bashrc' }"
        '        exit 0'
        '    }'
        '    default { exit 0 }'
        '}'
    )
    Set-Content -LiteralPath $worker -Value $body -Encoding ASCII

    if ($env:OS -eq 'Windows_NT') {
        $path = Join-Path $Directory 'git.cmd'
        $lines = @(
            '@echo off'
            ">>`"$log`" echo %*"
            "`"$PowerShellExe`" -NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$worker`" %*"
            'exit /b %ERRORLEVEL%'
        )
    }
    else {
        $path = Join-Path $Directory 'git'
        $lines = @(
            '#!/bin/sh'
            "printf '%s\n' `"`$*`" >>'$log'"
            "exec '$PowerShellExe' -NoLogo -NoProfile -File '$worker' `"`$@`""
        )
    }

    Set-Content -LiteralPath $path -Value $lines -Encoding ASCII
    if ($env:OS -ne 'Windows_NT') {
        & chmod '+x' $path
    }

    return $log
}

function New-FakePwsh {
    <#
        PowerShell puts its own $PSHOME in front of PATH, so a fake pwsh only
        wins over the host pwsh when it is the Scoop shim that install.ps1
        prefers.
    #>
    param(
        [Parameter(Mandatory)]
        $Sandbox
    )

    $shims = Join-Path $Sandbox.Scoop 'shims'
    New-Item -ItemType Directory -Force -Path $shims | Out-Null

    return New-FakeExecutable -Directory $shims -Name 'pwsh'
}

function Get-SandboxHomeEntry {
    <#
        Everything the sandbox home holds, except the AppData directory that
        Windows PowerShell creates for %USERPROFILE% on its own. Used to assert
        that a run wrote no dotfiles into the home directory.
    #>
    param(
        [Parameter(Mandatory)]
        $Sandbox
    )

    $entries = @(Get-ChildItem -LiteralPath $Sandbox.Home -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne 'AppData' })

    Write-Output $entries -NoEnumerate
}

function Invoke-SandboxProcess {
    <#
        Runs a program in a child process with a controlled environment and
        PATH. The environment of the test process itself is never modified,
        HOME/USERPROFILE and SCOOP point into the sandbox, and HTTPS_PROXY
        points at a closed port so that no test can reach the network.
    #>
    param(
        [Parameter(Mandatory)]
        $Sandbox,

        [Parameter(Mandatory)]
        [string]$FilePath,

        [string[]]$Arguments = @(),

        [string]$WorkingDirectory,

        [string[]]$PathEntries,

        [hashtable]$ExtraEnvironment = @{}
    )

    if (-not $WorkingDirectory) {
        $WorkingDirectory = $Sandbox.Elsewhere
    }
    if (-not $PathEntries) {
        $PathEntries = @($Sandbox.Bin)
    }
    if ($env:OS -eq 'Windows_NT') {
        $PathEntries = $PathEntries + (Join-Path $env:SystemRoot 'System32')
    }

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $FilePath
    $startInfo.Arguments = ($Arguments | ForEach-Object {
            if ($_ -match '\s') { '"' + $_ + '"' } else { $_ }
        }) -join ' '
    $startInfo.WorkingDirectory = $WorkingDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true

    $environment = $startInfo.EnvironmentVariables
    foreach ($name in @($environment.Keys | Where-Object { $_ -like 'CHEZMOI_*' })) {
        $environment.Remove($name)
    }
    $environment.Remove('SCOOP_GLOBAL')
    # A marker of an outer run must never leak into a bootstrap under test.
    $environment.Remove('DOTFILES_BOOTSTRAP')
    $environment['PATH'] = $PathEntries -join [IO.Path]::PathSeparator
    $environment['HOME'] = $Sandbox.Home
    $environment['USERPROFILE'] = $Sandbox.Home
    $environment['SCOOP'] = $Sandbox.Scoop
    $environment['XDG_CONFIG_HOME'] = Join-Path $Sandbox.Home '.config'
    $environment['XDG_DATA_HOME'] = Join-Path $Sandbox.Home '.local/share'
    # Outside the sandbox home, so that 'the home directory stayed empty'
    # assertions are not defeated by a shell writing its own cache.
    $environment['XDG_CACHE_HOME'] = Join-Path $Sandbox.Root 'cache'
    # Outside the sandbox home like the cache, so that Windows creating
    # %APPDATA% does not defeat 'the home directory stayed empty' assertions.
    $environment['APPDATA'] = Join-Path $Sandbox.Root 'AppData\Roaming'
    $environment['LOCALAPPDATA'] = Join-Path $Sandbox.Root 'AppData\Local'
    $environment['HTTPS_PROXY'] = 'http://127.0.0.1:9'
    foreach ($name in $ExtraEnvironment.Keys) {
        $environment[$name] = $ExtraEnvironment[$name]
    }

    $process = [Diagnostics.Process]::Start($startInfo)
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    return [pscustomobject]@{
        ExitCode = $process.ExitCode
        StdOut   = $stdout
        StdErr   = $stderr
    }
}

function Invoke-InstallScript {
    <#
        Runs install.ps1 from the repository copy (repository-local mode), or
        with -Standalone the downloaded copy that has no repository around it
        (bootstrap mode).
    #>
    param(
        [Parameter(Mandatory)]
        $Sandbox,

        [string]$WorkingDirectory,

        [string[]]$Arguments = @(),

        [string[]]$PathEntries,

        [hashtable]$ExtraEnvironment = @{},

        [switch]$Standalone
    )

    $script = $Sandbox.Script
    if ($Standalone) {
        $script = $Sandbox.Standalone
    }

    return Invoke-SandboxProcess -Sandbox $Sandbox -FilePath $PowerShellExe -Arguments (@(
            '-NoLogo'
            '-NoProfile'
            '-NonInteractive'
            '-ExecutionPolicy', 'Bypass'
            '-File', $script
        ) + $Arguments) -WorkingDirectory $WorkingDirectory -PathEntries $PathEntries `
        -ExtraEnvironment $ExtraEnvironment
}

function Invoke-SandboxChezmoi {
    <#
        Runs the real chezmoi against the sandbox home, so that chezmoi itself,
        not a reimplementation of it, decides whether this source state applies.
    #>
    param(
        [Parameter(Mandatory)]
        $Sandbox,

        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    $toolPath = @(Split-Path -Parent $RealChezmoi)
    if ($RealGit) {
        $toolPath += Split-Path -Parent $RealGit
    }

    return Invoke-SandboxProcess -Sandbox $Sandbox -FilePath $RealChezmoi `
        -Arguments (@('--no-tty') + $Arguments) `
        -PathEntries ($toolPath | Select-Object -Unique)
}
