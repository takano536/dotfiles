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

$RealChezmoi = Get-Command 'chezmoi' -CommandType Application -ErrorAction SilentlyContinue |
    Select-Object -First 1 -ExpandProperty Source
$RealGit = Get-Command 'git' -CommandType Application -ErrorAction SilentlyContinue |
    Select-Object -First 1 -ExpandProperty Source

function New-Sandbox {
    <#
        Creates an isolated copy of the installable part of the repository plus
        a fake HOME and a directory for fake executables. The repository copy
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
    foreach ($directory in @($repo, $sandboxHome, $bin, $elsewhere)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    Copy-Item -LiteralPath (Join-Path $RepoRoot 'install.ps1') -Destination $repo
    Copy-Item -LiteralPath (Join-Path $RepoRoot '.chezmoiroot') -Destination $repo
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'home') -Destination $repo -Recurse

    return [pscustomobject]@{
        Root      = $root
        Repo      = $repo
        Script    = Join-Path $repo 'install.ps1'
        Home      = $sandboxHome
        Bin       = $bin
        Elsewhere = $elsewhere
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

function Invoke-InstallScript {
    <#
        Runs install.ps1 in a child process with a controlled environment and
        PATH. The environment of the test process itself is never modified, and
        HOME/USERPROFILE point into the sandbox, so the real home directory of
        the user cannot be written to.
    #>
    param(
        [Parameter(Mandatory)]
        $Sandbox,

        [string]$WorkingDirectory,

        [string[]]$Arguments = @(),

        [string[]]$PathEntries
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
    $startInfo.FileName = $PowerShellExe
    $startInfo.Arguments = (@(
            '-NoLogo'
            '-NoProfile'
            '-NonInteractive'
            '-ExecutionPolicy', 'Bypass'
            '-File', ('"' + $Sandbox.Script + '"')
        ) + $Arguments) -join ' '
    $startInfo.WorkingDirectory = $WorkingDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true

    $environment = $startInfo.EnvironmentVariables
    foreach ($name in @($environment.Keys | Where-Object { $_ -like 'CHEZMOI_*' })) {
        $environment.Remove($name)
    }
    $environment.Remove('SCOOP')
    $environment['PATH'] = $PathEntries -join [IO.Path]::PathSeparator
    $environment['HOME'] = $Sandbox.Home
    $environment['USERPROFILE'] = $Sandbox.Home
    $environment['XDG_CONFIG_HOME'] = Join-Path $Sandbox.Home '.config'
    $environment['APPDATA'] = Join-Path $Sandbox.Home 'AppData\Roaming'
    $environment['LOCALAPPDATA'] = Join-Path $Sandbox.Home 'AppData\Local'

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
