<#
    Pester tests for install.ps1.

    Run with:
        Invoke-Pester -Path .\tests

    install.ps1 is executed as a child process with a temporary HOME and a PATH
    that only contains fake executables, so the real home directory of the user
    is never touched. The last context uses the real chezmoi binary when it is
    installed, still against a temporary HOME.
#>

#Requires -Version 5.1

. (Join-Path $PSScriptRoot 'TestHelpers.ps1')

Describe 'install.ps1' {

    BeforeAll {
        . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    }

    Context 'when every prerequisite is available' {

        BeforeAll {
            $sandbox = New-Sandbox
            New-FakeExecutable -Directory $sandbox.Bin -Name 'git' | Out-Null
            $chezmoiLog = New-FakeExecutable -Directory $sandbox.Bin -Name 'chezmoi'
            $result = Invoke-InstallScript -Sandbox $sandbox
        }

        AfterAll {
            Remove-Sandbox -Sandbox $sandbox
        }

        It 'succeeds' {
            $result.ExitCode | Should -Be 0
            $result.StdErr | Should -BeNullOrEmpty
        }

        It 'reports the prerequisite, apply and completion steps' {
            $result.StdOut | Should -Match 'Checking prerequisites'
            $result.StdOut | Should -Match 'Applying dotfiles with chezmoi'
            $result.StdOut | Should -Match 'Done'
        }

        It 'runs chezmoi init --apply exactly once' {
            $invocations = Get-FakeInvocation -LogPath $chezmoiLog
            $invocations.Count | Should -Be 1
            $invocations[0] | Should -Match 'init'
            $invocations[0] | Should -Match '--apply'
        }

        It 'passes the repository root as chezmoi source although the working directory is elsewhere' {
            $invocations = Get-FakeInvocation -LogPath $chezmoiLog
            $invocations[0] | Should -Match ([regex]::Escape('--source'))
            $invocations[0] | Should -Match ([regex]::Escape($sandbox.Repo))
        }

        It 'targets the home directory tracked in this repository' {
            # .chezmoiroot makes home/ the chezmoi source state, so the source
            # handed to chezmoi has to contain it.
            (Get-Content -LiteralPath (Join-Path $sandbox.Repo '.chezmoiroot') -Raw).Trim() |
                Should -Be 'home'
            Join-Path $sandbox.Repo 'home' | Should -Exist
            Join-Path $sandbox.Repo 'home/.chezmoi.toml.tmpl' | Should -Exist
        }
    }

    Context 'when run twice' {

        BeforeAll {
            $sandbox = New-Sandbox
            New-FakeExecutable -Directory $sandbox.Bin -Name 'git' | Out-Null
            $chezmoiLog = New-FakeExecutable -Directory $sandbox.Bin -Name 'chezmoi'
            $first = Invoke-InstallScript -Sandbox $sandbox
            $second = Invoke-InstallScript -Sandbox $sandbox
        }

        AfterAll {
            Remove-Sandbox -Sandbox $sandbox
        }

        It 'succeeds both times' {
            $first.ExitCode | Should -Be 0
            $second.ExitCode | Should -Be 0
        }

        It 'issues the same single chezmoi command per run without accumulating work' {
            $invocations = Get-FakeInvocation -LogPath $chezmoiLog
            $invocations.Count | Should -Be 2
            $invocations[1] | Should -Be $invocations[0]
        }
    }

    Context 'when -DryRun is used' {

        BeforeAll {
            $sandbox = New-Sandbox
            New-FakeExecutable -Directory $sandbox.Bin -Name 'git' | Out-Null
            $chezmoiLog = New-FakeExecutable -Directory $sandbox.Bin -Name 'chezmoi'
            $result = Invoke-InstallScript -Sandbox $sandbox -Arguments @('-DryRun')
        }

        AfterAll {
            Remove-Sandbox -Sandbox $sandbox
        }

        It 'asks chezmoi for a dry run and reports that nothing changed' {
            $result.ExitCode | Should -Be 0
            (Get-FakeInvocation -LogPath $chezmoiLog)[0] | Should -Match '--dry-run'
            $result.StdOut | Should -Match 'Dry run complete'
        }
    }

    Context 'when a prerequisite is missing' {

        BeforeEach {
            $sandbox = New-Sandbox
        }

        AfterEach {
            Remove-Sandbox -Sandbox $sandbox
        }

        It 'fails when git is missing' {
            New-FakeExecutable -Directory $sandbox.Bin -Name 'chezmoi' | Out-Null

            $result = Invoke-InstallScript -Sandbox $sandbox

            $result.ExitCode | Should -Not -Be 0
            $result.StdErr | Should -Match 'git was not found'
            $result.StdErr | Should -Match 'scoop install git'
        }

        It 'fails with installation instructions when chezmoi is missing and cannot be installed' {
            New-FakeExecutable -Directory $sandbox.Bin -Name 'git' | Out-Null

            $result = Invoke-InstallScript -Sandbox $sandbox

            $result.ExitCode | Should -Not -Be 0
            $result.StdErr | Should -Match 'chezmoi was not found'
            $result.StdErr | Should -Match 'scoop install chezmoi'
            $result.StdErr | Should -Match ([regex]::Escape('winget install twpayne.chezmoi'))
        }

        It 'fails without attempting an installation when -SkipChezmoiInstall is used' {
            New-FakeExecutable -Directory $sandbox.Bin -Name 'git' | Out-Null
            $scoopLog = New-FakeExecutable -Directory $sandbox.Bin -Name 'scoop'

            $result = Invoke-InstallScript -Sandbox $sandbox -Arguments @('-SkipChezmoiInstall')

            $result.ExitCode | Should -Not -Be 0
            $result.StdErr | Should -Match 'SkipChezmoiInstall'
            (Get-FakeInvocation -LogPath $scoopLog).Count | Should -Be 0
        }

        It 'installs chezmoi with scoop when scoop is the available package manager' {
            New-FakeExecutable -Directory $sandbox.Bin -Name 'git' | Out-Null
            $scoopLog = New-FakeExecutable -Directory $sandbox.Bin -Name 'scoop'

            $result = Invoke-InstallScript -Sandbox $sandbox

            (Get-FakeInvocation -LogPath $scoopLog)[0] | Should -Match 'install chezmoi'
            # scoop is faked, so chezmoi is still missing afterwards and the run
            # must fail loudly instead of reporting success.
            $result.ExitCode | Should -Not -Be 0
            $result.StdErr | Should -Match 'still not on PATH'
        }

        It 'leaves the home directory untouched' {
            New-FakeExecutable -Directory $sandbox.Bin -Name 'git' | Out-Null

            Invoke-InstallScript -Sandbox $sandbox | Out-Null

            Get-ChildItem -LiteralPath $sandbox.Home -Force | Should -HaveCount 0
        }

        It 'fails when the script is not inside the dotfiles repository' {
            New-FakeExecutable -Directory $sandbox.Bin -Name 'git' | Out-Null
            New-FakeExecutable -Directory $sandbox.Bin -Name 'chezmoi' | Out-Null
            Remove-Item -LiteralPath (Join-Path $sandbox.Repo '.chezmoiroot') -Force

            $result = Invoke-InstallScript -Sandbox $sandbox

            $result.ExitCode | Should -Not -Be 0
            $result.StdErr | Should -Match ([regex]::Escape('.chezmoiroot'))
        }
    }

    Context 'when chezmoi fails' {

        BeforeAll {
            $sandbox = New-Sandbox
            New-FakeExecutable -Directory $sandbox.Bin -Name 'git' | Out-Null
            New-FakeExecutable -Directory $sandbox.Bin -Name 'chezmoi' -ExitCode 7 | Out-Null
            $result = Invoke-InstallScript -Sandbox $sandbox
        }

        AfterAll {
            Remove-Sandbox -Sandbox $sandbox
        }

        It 'propagates the exit code of chezmoi' {
            $result.ExitCode | Should -Be 7
        }

        It 'explains what to check next without a stack trace' {
            $result.StdErr | Should -Match 'chezmoi exited with code 7'
            $result.StdErr | Should -Match 'chezmoi doctor'
            $result.StdErr | Should -Not -Match 'ScriptStackTrace'
        }

        It 'does not claim completion' {
            $result.StdOut | Should -Not -Match 'Done'
        }
    }

    Context 'Windows PowerShell 5.1 compatibility' {

        BeforeAll {
            $installPath = Join-Path $RepoRoot 'install.ps1'
            $tokens = $null
            $errors = $null
            [System.Management.Automation.Language.Parser]::ParseFile(
                $installPath, [ref]$tokens, [ref]$errors) | Out-Null
        }

        It 'parses without errors' {
            @($errors) | Should -HaveCount 0
        }

        It 'declares the minimum PowerShell version' {
            Get-Content -LiteralPath $installPath -Raw | Should -Match '#Requires -Version 5\.1'
        }

        It 'uses no PowerShell 7 only operators' {
            # ?? and ??=, ?. and ?[ , ternary ? : , pipeline chains && and ||.
            $ps7Operators = @(
                'QuestionQuestion'
                'QuestionQuestionEquals'
                'QuestionDot'
                'QuestionLBracket'
                'QuestionMark'
                'AndAnd'
                'OrOr'
            )
            $found = @($tokens | Where-Object { $ps7Operators -contains $_.Kind.ToString() })
            $found | Should -HaveCount 0
        }

        It 'uses no PowerShell 7 only automatic variables' {
            $names = @($tokens |
                    Where-Object { $_ -is [System.Management.Automation.Language.VariableToken] } |
                    ForEach-Object { $_.Name })
            $names | Should -Not -Contain 'IsWindows'
            $names | Should -Not -Contain 'IsLinux'
            $names | Should -Not -Contain 'IsMacOS'
            $names | Should -Not -Contain 'IsCoreCLR'
        }

        It 'is pure ASCII so Windows PowerShell reads it without a BOM' {
            $bytes = [IO.File]::ReadAllBytes($installPath)
            @($bytes | Where-Object { $_ -gt 127 }) | Should -HaveCount 0
        }
    }

    Context 'end-to-end with the real chezmoi binary' -Skip:(-not ($RealChezmoi -and $RealGit)) {

        BeforeAll {
            $sandbox = New-Sandbox
            $toolPath = @(
                Split-Path -Parent $RealChezmoi
                Split-Path -Parent $RealGit
            ) | Select-Object -Unique
            $first = Invoke-InstallScript -Sandbox $sandbox -PathEntries $toolPath
            $second = Invoke-InstallScript -Sandbox $sandbox -PathEntries $toolPath
        }

        AfterAll {
            Remove-Sandbox -Sandbox $sandbox
        }

        It 'applies the repository into the temporary home directory' {
            $first.ExitCode | Should -Be 0
            Join-Path $sandbox.Home '.config/git/config' | Should -Exist
            Join-Path $sandbox.Home '.config/nvim/init.lua' | Should -Exist
            Join-Path $sandbox.Home '.bashrc' | Should -Exist
        }

        It 'renders the git configuration template' {
            $config = Get-Content -LiteralPath (Join-Path $sandbox.Home '.config/git/config') -Raw
            $config | Should -Match 'takano536'
        }

        It 'records this repository as the chezmoi source directory' {
            $chezmoiConfig = Join-Path $sandbox.Home '.config/chezmoi/chezmoi.toml'
            $chezmoiConfig | Should -Exist

            # sourceDir = "<path>", with backslashes TOML escaped on Windows.
            $sourceDir = (Get-Content -LiteralPath $chezmoiConfig -Raw).Trim() `
                -replace '^sourceDir\s*=\s*"', '' -replace '"$', '' -replace '\\\\', '\'
            $sourceDir | Should -Be (Join-Path $sandbox.Repo 'home')
        }

        It 'stays successful and stable on the second run' {
            $second.ExitCode | Should -Be 0
            $second.StdOut | Should -Match 'Done'
        }

        It 'applies the Windows profiles only on Windows' -Skip:(-not $OnWindows) {
            Join-Path $sandbox.Home 'Documents/PowerShell/profile.ps1' | Should -Exist
            Join-Path $sandbox.Home 'Documents/WindowsPowerShell/profile.ps1' | Should -Exist
        }
    }

    Context 'dry run with the real chezmoi binary' -Skip:(-not ($RealChezmoi -and $RealGit)) {

        BeforeAll {
            $sandbox = New-Sandbox
            $toolPath = @(
                Split-Path -Parent $RealChezmoi
                Split-Path -Parent $RealGit
            ) | Select-Object -Unique
            $result = Invoke-InstallScript -Sandbox $sandbox -PathEntries $toolPath -Arguments @('-DryRun')
        }

        AfterAll {
            Remove-Sandbox -Sandbox $sandbox
        }

        It 'writes nothing into the home directory' {
            $result.ExitCode | Should -Be 0
            $result.StdOut | Should -Match 'Dry run complete'
            Get-ChildItem -LiteralPath $sandbox.Home -Force | Should -HaveCount 0
        }
    }
}
