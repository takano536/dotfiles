<#
    Pester tests for install.ps1 and packages/windows.psd1.

    Run with:
        Invoke-Pester -Path .\tests

    install.ps1 is executed as a child process with a temporary HOME, a
    temporary Scoop root, a PATH that only contains fake executables and a
    HTTPS_PROXY that points at a closed port. The real home directory, the real
    Scoop installation and the network are therefore never touched. The last
    two contexts use the real chezmoi binary when it is installed, still
    against a temporary HOME and with -SkipPackages.
#>

#Requires -Version 5.1

. (Join-Path $PSScriptRoot 'TestHelpers.ps1')

Describe 'packages/windows.psd1' {

    BeforeAll {
        . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
        $packageFile = Join-Path (Join-Path $RepoRoot 'packages') 'windows.psd1'
        $packages = Import-PowerShellDataFile -LiteralPath $packageFile
        $allPackages = @($packages.Required) + @($packages.Optional)
    }

    It 'loads with Import-PowerShellDataFile, which Windows PowerShell 5.1 also has' {
        $packages | Should -BeOfType [hashtable]
        $packages.Keys | Should -Contain 'Required'
        $packages.Keys | Should -Contain 'Optional'
        $packages.Keys | Should -Contain 'Buckets'
        $packages.Keys | Should -Contain 'PSModules'
    }

    It 'classifies the packages the applied dotfiles need as required' {
        $required = $packages.Required | ForEach-Object { $_.Scoop }
        $required | Should -Contain 'git'
        $required | Should -Contain 'pwsh'
        $required | Should -Contain 'neovim'
        $required | Should -Contain 'starship'
        $required | Should -Contain 'chezmoi'
    }

    It 'classifies the everyday CLI and TUI tools as optional' {
        $optional = $packages.Optional | ForEach-Object { $_.Scoop }
        $optional | Should -Contain 'zoxide'
        $optional | Should -Contain 'eza'
        $optional | Should -Contain 'lazygit'
        $optional | Should -Contain 'btop'
        $optional.Count | Should -BeGreaterThan 5
    }

    It 'keeps the Treesitter build tools as optional packages' {
        # .config/nvim/after/plugin/treesitter.rc.lua sets CC=gcc on Windows and
        # installs parsers, so both are part of a default run.
        $optional = $packages.Optional | ForEach-Object { $_.Scoop }
        $optional | Should -Contain 'tree-sitter'
        $optional | Should -Contain 'gcc'
        @($packages.Required | ForEach-Object { $_.Scoop }) | Should -Not -Contain 'gcc'
    }

    It 'describes every package with a scoop name, a command and a reason' {
        foreach ($package in $allPackages) {
            $package.Scoop | Should -Not -BeNullOrEmpty
            $package.Command | Should -Not -BeNullOrEmpty
            $package.Why | Should -Not -BeNullOrEmpty
        }
    }

    It 'defines no winget metadata, because Scoop is the only package manager' {
        foreach ($package in $allPackages) {
            $package.Keys | Should -Not -Contain 'Winget'
        }
        Get-Content -LiteralPath $packageFile -Raw | Should -Not -Match 'winget'
    }

    It 'lists no package twice' {
        $names = $allPackages | ForEach-Object { $_.Scoop }
        ($names | Select-Object -Unique).Count | Should -Be $names.Count
    }

    It 'declares only the buckets that are actually needed' {
        # main ships with Scoop, extras only provides lazygit.
        $packages.Buckets | Should -Be @('main', 'extras')
    }

    It 'installs the PowerShell modules that the profile imports' {
        $packages.PSModules | Should -Contain 'Terminal-Icons'
        $packages.PSModules | Should -Contain 'CompletionPredictor'
        $packages.PSModules | Should -Contain 'PowerType'
    }

    It 'bootstraps no AI coding agent, container, runtime or GUI application' {
        $names = @($allPackages | ForEach-Object { $_.Scoop }) + @($packages.PSModules)
        foreach ($forbidden in @(
                'omp', 'oh-my-pi', 'claude', 'claude-code', 'codex', 'codex-cli',
                'aider', 'copilot', 'docker', 'docker-desktop', 'wsl',
                'bun', 'nodejs', 'node', 'python', 'firefox', 'sublime-text',
                'zed', 'windows-terminal', 'vscode', 'googlechrome')) {
            $names | Should -Not -Contain $forbidden
        }
    }
}

Describe 'install.ps1' {

    BeforeAll {
        . (Join-Path $PSScriptRoot 'TestHelpers.ps1')

        $packageData = Import-PowerShellDataFile -LiteralPath (
            Join-Path (Join-Path $RepoRoot 'packages') 'windows.psd1')
        $requiredNames = @($packageData.Required | ForEach-Object { $_.Scoop })
        $optionalNames = @($packageData.Optional | ForEach-Object { $_.Scoop })
    }

    Context 'when Scoop, chezmoi and pwsh are available' {

        BeforeAll {
            $sandbox = New-Sandbox
            $scoopLog = New-FakeScoop -Directory $sandbox.Bin -ScoopRoot $sandbox.Scoop
            $chezmoiLog = New-FakeExecutable -Directory $sandbox.Bin -Name 'chezmoi'
            $pwshLog = New-FakePwsh -Sandbox $sandbox
            $result = Invoke-InstallScript -Sandbox $sandbox
            $scoopCalls = Get-FakeInvocation -LogPath $scoopLog
        }

        AfterAll {
            Remove-Sandbox -Sandbox $sandbox
        }

        It 'succeeds' {
            $result.ExitCode | Should -Be 0
            $result.StdErr | Should -BeNullOrEmpty
        }

        It 'reports the bootstrap steps' {
            $result.StdOut | Should -Match 'Checking prerequisites'
            $result.StdOut | Should -Match 'Ensuring Scoop'
            $result.StdOut | Should -Match 'Installing required packages'
            $result.StdOut | Should -Match 'Installing optional CLI and TUI packages'
            $result.StdOut | Should -Match 'Applying dotfiles with chezmoi'
            $result.StdOut | Should -Match 'Summary'
            $result.StdOut | Should -Match 'Done'
        }

        It 'does not bootstrap Scoop when Scoop is already installed' {
            $result.StdOut | Should -Match ([regex]::Escape($sandbox.Bin))
            $result.StdOut | Should -Not -Match 'downloading'
            $result.StdOut | Should -Not -Match 'would bootstrap Scoop'
        }

        It 'adds only the declared Scoop buckets' {
            $bucketCalls = @($scoopCalls | Where-Object { $_ -match 'bucket add' })
            $bucketCalls | Should -HaveCount 2
            $bucketCalls -join ' ' | Should -Match 'bucket add main'
            $bucketCalls -join ' ' | Should -Match 'bucket add extras'
        }

        It 'installs the missing required packages with scoop' {
            $installed = @($scoopCalls | Where-Object { $_ -like 'install *' } |
                    ForEach-Object { $_ -replace '^install\s+', '' })
            foreach ($name in @('git', 'neovim', 'starship')) {
                $installed | Should -Contain $name
            }
        }

        It 'skips the packages that are already on PATH' {
            # chezmoi and pwsh are provided as fake executables.
            $result.StdOut | Should -Match 'present: chezmoi'
            $result.StdOut | Should -Match 'present: pwsh'
            $scoopCalls -join ' ' | Should -Not -Match 'install chezmoi'
            $scoopCalls -join ' ' | Should -Not -Match 'install pwsh'
        }

        It 'installs every optional package with scoop' {
            $installed = @($scoopCalls | Where-Object { $_ -like 'install *' } |
                    ForEach-Object { $_ -replace '^install\s+', '' })
            foreach ($name in $optionalNames) {
                $installed | Should -Contain $name
            }
        }

        It 'installs the PowerShell modules with pwsh' {
            # The command spans several lines in the log of the fake pwsh.
            $pwshCalls = Get-FakeInvocation -LogPath $pwshLog
            @($pwshCalls | Where-Object { $_ -match '-NoProfile' }) | Should -HaveCount 1
            $payload = $pwshCalls -join "`n"
            $payload | Should -Match 'Install-Module'
            $payload | Should -Match 'Get-Module -ListAvailable'
            $payload | Should -Match 'Terminal-Icons'
            $payload | Should -Match 'CompletionPredictor'
            $payload | Should -Match 'PowerType'
        }

        It 'runs chezmoi init --apply once with the repository root as source' {
            $chezmoiCalls = Get-FakeInvocation -LogPath $chezmoiLog
            $chezmoiCalls | Should -HaveCount 1
            $chezmoiCalls[0] | Should -Match 'init'
            $chezmoiCalls[0] | Should -Match '--apply'
            $chezmoiCalls[0] | Should -Match ([regex]::Escape('--source'))
            # The repository copy contains a space and is not the working directory.
            $chezmoiCalls[0] | Should -Match ([regex]::Escape($sandbox.Repo))
        }

        It 'targets the home directory tracked in this repository' {
            (Get-Content -LiteralPath (Join-Path $sandbox.Repo '.chezmoiroot') -Raw).Trim() |
                Should -Be 'home'
            Join-Path $sandbox.Repo 'home/.chezmoi.toml.tmpl' | Should -Exist
        }
    }

    Context 'when packages are already installed' {

        BeforeAll {
            $sandbox = New-Sandbox
            foreach ($name in @('git', 'neovim', 'btop')) {
                New-Item -ItemType Directory -Force -Path (
                    Join-Path (Join-Path $sandbox.Scoop 'apps') (Join-Path $name 'current')) | Out-Null
            }
            $scoopLog = New-FakeScoop -Directory $sandbox.Bin -ScoopRoot $sandbox.Scoop
            New-FakeExecutable -Directory $sandbox.Bin -Name 'chezmoi' | Out-Null
            New-FakePwsh -Sandbox $sandbox | Out-Null
            $result = Invoke-InstallScript -Sandbox $sandbox
            $scoopCalls = Get-FakeInvocation -LogPath $scoopLog
        }

        AfterAll {
            Remove-Sandbox -Sandbox $sandbox
        }

        It 'does not reinstall packages that Scoop already manages' {
            $result.ExitCode | Should -Be 0
            foreach ($name in @('git', 'neovim', 'btop')) {
                $result.StdOut | Should -Match "present: $name"
                $scoopCalls -join ' ' | Should -Not -Match "install $name"
            }
        }

        It 'still installs the packages that are missing' {
            $scoopCalls -join ' ' | Should -Match 'install starship'
        }
    }

    Context 'when run twice' {

        BeforeAll {
            $sandbox = New-Sandbox
            $scoopLog = New-FakeScoop -Directory $sandbox.Bin -ScoopRoot $sandbox.Scoop
            $chezmoiLog = New-FakeExecutable -Directory $sandbox.Bin -Name 'chezmoi'
            New-FakePwsh -Sandbox $sandbox | Out-Null

            $first = Invoke-InstallScript -Sandbox $sandbox
            $callsAfterFirst = (Get-FakeInvocation -LogPath $scoopLog).Count
            $second = Invoke-InstallScript -Sandbox $sandbox
            $callsAfterSecond = (Get-FakeInvocation -LogPath $scoopLog).Count
        }

        AfterAll {
            Remove-Sandbox -Sandbox $sandbox
        }

        It 'succeeds both times' {
            $first.ExitCode | Should -Be 0
            $second.ExitCode | Should -Be 0
        }

        It 'installs nothing and adds no bucket on the second run' {
            $callsAfterFirst | Should -BeGreaterThan 0
            $callsAfterSecond | Should -Be $callsAfterFirst
        }

        It 'issues the same single chezmoi command per run' {
            $chezmoiCalls = Get-FakeInvocation -LogPath $chezmoiLog
            $chezmoiCalls | Should -HaveCount 2
            $chezmoiCalls[1] | Should -Be $chezmoiCalls[0]
        }
    }

    Context 'when packages are skipped' {

        BeforeAll {
            $sandbox = New-Sandbox
            $scoopLog = New-FakeScoop -Directory $sandbox.Bin -ScoopRoot $sandbox.Scoop
            $chezmoiLog = New-FakeExecutable -Directory $sandbox.Bin -Name 'chezmoi'
            New-FakePwsh -Sandbox $sandbox | Out-Null
            $skipAll = Invoke-InstallScript -Sandbox $sandbox -Arguments @('-SkipPackages')
            $callsAfterSkipAll = (Get-FakeInvocation -LogPath $scoopLog).Count
            $chezmoiAfterSkipAll = (Get-FakeInvocation -LogPath $chezmoiLog).Count
            $skipOptional = Invoke-InstallScript -Sandbox $sandbox -Arguments @('-SkipOptional')
            $optionalCalls = Get-FakeInvocation -LogPath $scoopLog
        }

        AfterAll {
            Remove-Sandbox -Sandbox $sandbox
        }

        It '-SkipPackages installs nothing but still applies the dotfiles' {
            $skipAll.ExitCode | Should -Be 0
            $callsAfterSkipAll | Should -Be 0
            $skipAll.StdOut | Should -Match 'Package bootstrap skipped'
            $chezmoiAfterSkipAll | Should -Be 1
        }

        It '-SkipOptional installs the required packages only' {
            $skipOptional.ExitCode | Should -Be 0
            $skipOptional.StdOut | Should -Match 'Optional CLI and TUI packages skipped'
            $optionalCalls -join ' ' | Should -Match 'install neovim'
            foreach ($name in $optionalNames) {
                $optionalCalls -join ' ' | Should -Not -Match "install $([regex]::Escape($name))\b"
            }
        }
    }

    Context 'when a required package cannot be installed' {

        BeforeAll {
            $sandbox = New-Sandbox
            $scoopLog = New-FakeScoop -Directory $sandbox.Bin -ScoopRoot $sandbox.Scoop -FailPattern 'neovim'
            $chezmoiLog = New-FakeExecutable -Directory $sandbox.Bin -Name 'chezmoi'
            New-FakePwsh -Sandbox $sandbox | Out-Null
            $result = Invoke-InstallScript -Sandbox $sandbox
        }

        AfterAll {
            Remove-Sandbox -Sandbox $sandbox
        }

        It 'fails and names the package' {
            $result.ExitCode | Should -Not -Be 0
            $result.StdOut | Should -Match 'required failures: neovim'
            $result.StdErr | Should -Match 'neovim'
        }

        It 'does not report completion' {
            $result.StdOut | Should -Not -Match 'Done, restart your shell'
        }

        It 'still installs the other packages' {
            (Get-FakeInvocation -LogPath $scoopLog) -join ' ' | Should -Match 'install starship'
        }
    }

    Context 'when an optional package cannot be installed' {

        BeforeAll {
            $sandbox = New-Sandbox
            $scoopLog = New-FakeScoop -Directory $sandbox.Bin -ScoopRoot $sandbox.Scoop -FailPattern 'btop'
            $chezmoiLog = New-FakeExecutable -Directory $sandbox.Bin -Name 'chezmoi'
            New-FakePwsh -Sandbox $sandbox | Out-Null
            $result = Invoke-InstallScript -Sandbox $sandbox
        }

        AfterAll {
            Remove-Sandbox -Sandbox $sandbox
        }

        It 'keeps going and succeeds' {
            $result.ExitCode | Should -Be 0
            $result.StdOut | Should -Match 'Done, restart your shell'
        }

        It 'lists the failure in the summary' {
            $result.StdOut | Should -Match 'optional failures: btop'
        }

        It 'still installs the other optional packages and applies the dotfiles' {
            (Get-FakeInvocation -LogPath $scoopLog) -join ' ' | Should -Match 'install yazi'
            (Get-FakeInvocation -LogPath $chezmoiLog) | Should -HaveCount 1
        }
    }

    Context 'when Scoop is missing' {

        BeforeEach {
            $sandbox = New-Sandbox
        }

        AfterEach {
            Remove-Sandbox -Sandbox $sandbox
        }

        It 'plans the Scoop bootstrap in a dry run without downloading anything' {
            New-FakeExecutable -Directory $sandbox.Bin -Name 'chezmoi' | Out-Null

            $result = Invoke-InstallScript -Sandbox $sandbox -Arguments @('-DryRun')

            $result.ExitCode | Should -Be 0
            $result.StdOut | Should -Match ([regex]::Escape('https://get.scoop.sh'))
            $result.StdOut | Should -Match ([regex]::Escape($sandbox.Scoop))
            $result.StdOut | Should -Match 'would add bucket: main'
            $result.StdOut | Should -Match 'would install with scoop: neovim'
            Get-ChildItem -LiteralPath $sandbox.Home -Force | Should -HaveCount 0
        }

        It 'aborts the run when the bootstrap fails' {
            # HTTPS_PROXY points at a closed port, so the download cannot succeed.
            New-FakeExecutable -Directory $sandbox.Bin -Name 'chezmoi' | Out-Null
            New-FakePwsh -Sandbox $sandbox | Out-Null

            $result = Invoke-InstallScript -Sandbox $sandbox

            $result.ExitCode | Should -Not -Be 0
            $result.StdOut | Should -Match 'Downloading the Scoop installer'
            $result.StdErr | Should -Match 'Scoop could not be bootstrapped'
            $result.StdErr | Should -Match ([regex]::Escape($sandbox.Scoop))
            $result.StdErr | Should -Match ([regex]::Escape('https://scoop.sh'))
        }

        It 'installs no package and applies nothing after a failed bootstrap' {
            $chezmoiLog = New-FakeExecutable -Directory $sandbox.Bin -Name 'chezmoi'
            New-FakePwsh -Sandbox $sandbox | Out-Null

            $result = Invoke-InstallScript -Sandbox $sandbox

            $result.StdOut | Should -Not -Match 'Installing required packages'
            $result.StdOut | Should -Not -Match 'Applying dotfiles with chezmoi'
            (Get-FakeInvocation -LogPath $chezmoiLog).Count | Should -Be 0
            Get-ChildItem -LiteralPath $sandbox.Home -Force | Should -HaveCount 0
        }

        It 'finds a Scoop shim that is not on PATH yet' {
            $shims = Join-Path $sandbox.Scoop 'shims'
            New-Item -ItemType Directory -Force -Path $shims | Out-Null
            $chezmoiLog = New-FakeExecutable -Directory $shims -Name 'chezmoi'

            $result = Invoke-InstallScript -Sandbox $sandbox -Arguments @('-SkipPackages')

            $result.ExitCode | Should -Be 0
            $result.StdOut | Should -Match ([regex]::Escape($shims))
            (Get-FakeInvocation -LogPath $chezmoiLog) | Should -HaveCount 1
        }
    }

    Context 'when chezmoi is missing' {

        BeforeEach {
            $sandbox = New-Sandbox
        }

        AfterEach {
            Remove-Sandbox -Sandbox $sandbox
        }

        It 'fails with Scoop installation instructions when Scoop cannot provide it' {
            $result = Invoke-InstallScript -Sandbox $sandbox -Arguments @('-SkipPackages')

            $result.ExitCode | Should -Not -Be 0
            $result.StdErr | Should -Match 'chezmoi was not found'
            $result.StdErr | Should -Match 'scoop install chezmoi'
            $result.StdErr | Should -Not -Match 'winget'
        }

        It 'fails without touching a package manager when -SkipChezmoiInstall is used' {
            $scoopLog = New-FakeScoop -Directory $sandbox.Bin -ScoopRoot $sandbox.Scoop

            $result = Invoke-InstallScript -Sandbox $sandbox -Arguments @('-SkipPackages', '-SkipChezmoiInstall')

            $result.ExitCode | Should -Not -Be 0
            $result.StdErr | Should -Match 'SkipChezmoiInstall'
            (Get-FakeInvocation -LogPath $scoopLog).Count | Should -Be 0
        }

        It 'installs chezmoi with scoop when only chezmoi is missing' {
            $scoopLog = New-FakeScoop -Directory $sandbox.Bin -ScoopRoot $sandbox.Scoop

            $result = Invoke-InstallScript -Sandbox $sandbox -Arguments @('-SkipPackages')

            # The fake scoop creates the app directory but no runnable shim, so
            # the run must fail loudly instead of reporting success.
            (Get-FakeInvocation -LogPath $scoopLog) -join ' ' | Should -Match 'install chezmoi'
            $result.ExitCode | Should -Not -Be 0
            $result.StdErr | Should -Match 'still not on PATH'
        }

        It 'leaves the home directory untouched' {
            Invoke-InstallScript -Sandbox $sandbox -Arguments @('-SkipPackages') | Out-Null

            Get-ChildItem -LiteralPath $sandbox.Home -Force | Should -HaveCount 0
        }

        It 'fails when the script is not inside the dotfiles repository' {
            New-FakeExecutable -Directory $sandbox.Bin -Name 'chezmoi' | Out-Null
            Remove-Item -LiteralPath (Join-Path $sandbox.Repo '.chezmoiroot') -Force

            $result = Invoke-InstallScript -Sandbox $sandbox -Arguments @('-SkipPackages')

            $result.ExitCode | Should -Not -Be 0
            $result.StdErr | Should -Match ([regex]::Escape('.chezmoiroot'))
        }

        It 'fails when the package list is missing' {
            New-FakeExecutable -Directory $sandbox.Bin -Name 'chezmoi' | Out-Null
            Remove-Item -LiteralPath (Join-Path $sandbox.Repo 'packages') -Recurse -Force

            $result = Invoke-InstallScript -Sandbox $sandbox

            $result.ExitCode | Should -Not -Be 0
            $result.StdErr | Should -Match ([regex]::Escape('windows.psd1'))
        }
    }

    Context 'when chezmoi fails' {

        BeforeAll {
            $sandbox = New-Sandbox
            New-FakeExecutable -Directory $sandbox.Bin -Name 'chezmoi' -ExitCode 7 | Out-Null
            $result = Invoke-InstallScript -Sandbox $sandbox -Arguments @('-SkipPackages')
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
            $result.StdOut | Should -Not -Match 'Done, restart your shell'
        }
    }

    Context 'when -DryRun is used' {

        BeforeAll {
            $sandbox = New-Sandbox
            $scoopLog = New-FakeScoop -Directory $sandbox.Bin -ScoopRoot $sandbox.Scoop
            $chezmoiLog = New-FakeExecutable -Directory $sandbox.Bin -Name 'chezmoi'
            $pwshLog = New-FakePwsh -Sandbox $sandbox
            $result = Invoke-InstallScript -Sandbox $sandbox -Arguments @('-DryRun')
        }

        AfterAll {
            Remove-Sandbox -Sandbox $sandbox
        }

        It 'shows the package plan without calling a package manager' {
            $result.ExitCode | Should -Be 0
            $result.StdOut | Should -Match 'would install with scoop: git'
            $result.StdOut | Should -Match 'would install with scoop: lazygit'
            $result.StdOut | Should -Match 'would install missing PowerShell modules'
            (Get-FakeInvocation -LogPath $scoopLog).Count | Should -Be 0
            (Get-FakeInvocation -LogPath $pwshLog).Count | Should -Be 0
        }

        It 'asks chezmoi for a dry run and changes nothing' {
            (Get-FakeInvocation -LogPath $chezmoiLog)[0] | Should -Match '--dry-run'
            $result.StdOut | Should -Match 'Dry run complete'
            Get-ChildItem -LiteralPath $sandbox.Home -Force | Should -HaveCount 0
        }
    }

    Context 'Windows PowerShell 5.1 compatibility' {

        BeforeAll {
            $installPath = Join-Path $RepoRoot 'install.ps1'
            $packagePath = Join-Path (Join-Path $RepoRoot 'packages') 'windows.psd1'
            $readmePath = Join-Path $RepoRoot 'README.md'
            $tokens = $null
            $errors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile(
                $installPath, [ref]$tokens, [ref]$errors)
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

        It 'uses no PowerShell 7 only cmdlets' {
            $commands = @($tokens |
                    Where-Object { $_.Kind.ToString() -eq 'Generic' } |
                    ForEach-Object { $_.Text })
            foreach ($ps7Only in @('Join-String', 'ConvertFrom-Markdown', 'Get-Uptime', 'Test-Json')) {
                $commands | Should -Not -Contain $ps7Only
            }
        }

        It 'keeps install.ps1 and the package list pure ASCII' {
            foreach ($path in @($installPath, $packagePath)) {
                $bytes = [IO.File]::ReadAllBytes($path)
                @($bytes | Where-Object { $_ -gt 127 }) | Should -HaveCount 0
            }
        }

        It 'holds no package name as a literal, so the package list is the only source' {
            $literals = @($tokens |
                    Where-Object { $_ -is [System.Management.Automation.Language.StringToken] } |
                    ForEach-Object { $_.Value })
            $packageNames = @($packageData.Required | ForEach-Object { $_.Scoop }) +
            @($packageData.Optional | ForEach-Object { $_.Scoop }) +
            @($packageData.PSModules)
            # chezmoi and pwsh are commands install.ps1 drives itself, every
            # other package name may only live in the package list.
            foreach ($name in $packageNames) {
                if (@('chezmoi', 'pwsh') -contains $name) { continue }
                $literals | Should -Not -Contain $name
            }
        }

        It 'uses the Scoop root that the PowerShell profile expects' {
            $envProfile = Get-Content -LiteralPath (
                Join-Path $RepoRoot 'home/Documents/PowerShell/Profile/env.ps1') -Raw
            $envProfile | Should -Match ([regex]::Escape('Programs\Scoop'))
            Get-Content -LiteralPath $installPath -Raw |
                Should -Match ([regex]::Escape('Programs\Scoop'))
        }

        It 'documents Windows PowerShell 5.1 as the bootstrap entry point' {
            $help = Get-Content -LiteralPath $installPath -Raw
            $help | Should -Match ([regex]::Escape('powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1'))
            Get-Content -LiteralPath $readmePath -Raw |
                Should -Match ([regex]::Escape('powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1'))
        }

        It 'requires no PowerShell 7 to start, only for the module step' {
            # Windows PowerShell 5.1 has to get all the way to 'scoop install
            # pwsh', so pwsh may only be resolved inside Install-PSModule.
            $lookups = $ast.FindAll({
                    param($node)
                    $node -is [System.Management.Automation.Language.CommandAst] -and
                    $node.GetCommandName() -eq 'Find-Executable' -and
                    $node.CommandElements.Count -gt 1 -and
                    "$($node.CommandElements[1])" -match 'pwsh'
                }, $true)
            $lookups.Count | Should -Be 1

            $enclosing = $lookups[0].Parent
            while ($enclosing -and -not ($enclosing -is [System.Management.Automation.Language.FunctionDefinitionAst])) {
                $enclosing = $enclosing.Parent
            }
            $enclosing.Name | Should -Be 'Install-PSModule'
            Get-Content -LiteralPath $installPath -Raw | Should -Not -Match '#Requires.*PSEdition'
        }

        It 'contains no winget code path anywhere' {
            foreach ($path in @($installPath, $packagePath, $readmePath,
                    (Join-Path $PSScriptRoot 'Install.Tests.ps1'),
                    (Join-Path $PSScriptRoot 'TestHelpers.ps1'))) {
                $content = Get-Content -LiteralPath $path -Raw
                # This test names winget itself, so only other files may not.
                if ($path -like '*Install.Tests.ps1') {
                    continue
                }
                $content | Should -Not -Match 'winget'
            }
        }
    }

    Context 'end-to-end with the real chezmoi binary' -Skip:(-not ($RealChezmoi -and $RealGit)) {

        BeforeAll {
            $sandbox = New-Sandbox
            $toolPath = @(
                Split-Path -Parent $RealChezmoi
                Split-Path -Parent $RealGit
            ) | Select-Object -Unique
            $first = Invoke-InstallScript -Sandbox $sandbox -PathEntries $toolPath -Arguments @('-SkipPackages')
            $second = Invoke-InstallScript -Sandbox $sandbox -PathEntries $toolPath -Arguments @('-SkipPackages')
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
            $result = Invoke-InstallScript -Sandbox $sandbox -PathEntries $toolPath `
                -Arguments @('-DryRun', '-SkipPackages')
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
