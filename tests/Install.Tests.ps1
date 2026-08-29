<#
    Behaviour tests for install.ps1 and the shape of packages/windows.psd1.

    Run with:
        Invoke-Pester -Path .\tests

    install.ps1 runs as a child process with a temporary HOME, a temporary
    Scoop root, a PATH that only holds fake executables and a HTTPS_PROXY that
    points at a closed port, so no test touches the real home directory, the
    real Scoop installation or the network.

    Package names are read from packages/windows.psd1: adding a package there
    needs no change here.
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

    It 'has the shape install.ps1 expects' {
        $packages | Should -BeOfType [hashtable]
        @($packages.Buckets).Count | Should -BeGreaterThan 0
        @($packages.Required).Count | Should -BeGreaterThan 0
        @($packages.Optional).Count | Should -BeGreaterThan 0
        @($packages.PSModules).Count | Should -BeGreaterThan 0
        foreach ($package in $allPackages) {
            $package | Should -BeOfType [hashtable]
        }
    }

    It 'gives every package a scoop name, a command and a reason' {
        foreach ($package in $allPackages) {
            $package.Scoop | Should -Not -BeNullOrEmpty
            $package.Command | Should -Not -BeNullOrEmpty
            $package.Why | Should -Not -BeNullOrEmpty
        }
    }

    It 'lists no package twice' {
        $names = @($allPackages | ForEach-Object { $_.Scoop })
        ($names | Select-Object -Unique).Count | Should -Be $names.Count
    }

    It 'defines no winget metadata, because Scoop is the only package manager' {
        foreach ($package in $allPackages) {
            $package.Keys | Should -Not -Contain 'Winget'
        }
        Get-Content -LiteralPath $packageFile -Raw | Should -Not -Match 'winget'
    }

    It 'bootstraps no AI coding agent and no heavyweight runtime' {
        $names = (@($allPackages | ForEach-Object { $_.Scoop }) + @($packages.PSModules)) -join ' '
        foreach ($forbidden in @('omp', 'claude', 'codex', 'bun', 'docker')) {
            $names | Should -Not -Match "\b$forbidden\b"
        }
    }
}

Describe 'install.ps1' {

    BeforeAll {
        . (Join-Path $PSScriptRoot 'TestHelpers.ps1')

        $packages = Import-PowerShellDataFile -LiteralPath (
            Join-Path (Join-Path $RepoRoot 'packages') 'windows.psd1')
        $requiredNames = @($packages.Required | ForEach-Object { $_.Scoop })
        $optionalNames = @($packages.Optional | ForEach-Object { $_.Scoop })

        function Get-ScoopCall {
            <#
                Returns the arguments of the fake scoop calls that start with
                the given verb, e.g. 'install' or 'bucket add'.
            #>
            param([string]$LogPath, [string]$Verb)

            $calls = Get-FakeInvocation -LogPath $LogPath
            return @($calls | Where-Object { $_ -like "$Verb *" } |
                    ForEach-Object { ($_ -replace "^$Verb\s+", '').Trim() })
        }
    }

    Context 'a normal run' {

        BeforeAll {
            $sandbox = New-Sandbox
            $scoopLog = New-FakeScoop -Directory $sandbox.Bin -ScoopRoot $sandbox.Scoop
            $chezmoiLog = New-FakeExecutable -Directory $sandbox.Bin -Name 'chezmoi'
            $pwshLog = New-FakePwsh -Sandbox $sandbox
            $result = Invoke-InstallScript -Sandbox $sandbox
        }

        AfterAll {
            Remove-Sandbox -Sandbox $sandbox
        }

        It 'succeeds and reports its steps' {
            $result.ExitCode | Should -Be 0
            $result.StdErr | Should -BeNullOrEmpty
            $result.StdOut | Should -Match 'Checking prerequisites'
            $result.StdOut | Should -Match 'Ensuring Scoop'
            $result.StdOut | Should -Match 'Applying dotfiles with chezmoi'
            $result.StdOut | Should -Match 'Summary'
            $result.StdOut | Should -Match 'Done'
        }

        It 'installs every package of the package list with scoop' {
            # chezmoi and pwsh are present as fake executables and must be skipped.
            $expected = @($requiredNames + $optionalNames |
                    Where-Object { @('chezmoi', 'pwsh') -notcontains $_ })
            (Get-ScoopCall -LogPath $scoopLog -Verb 'install') | Should -Be $expected
            $result.StdOut | Should -Match 'present: chezmoi'
        }

        It 'adds the declared buckets and no others' {
            (Get-ScoopCall -LogPath $scoopLog -Verb 'bucket add') |
                Should -Be @($packages.Buckets)
        }

        It 'hands the PowerShell modules of the package list to pwsh' {
            $payload = (Get-FakeInvocation -LogPath $pwshLog) -join "`n"
            $payload | Should -Match 'Install-Module'
            foreach ($module in $packages.PSModules) {
                $payload | Should -Match ([regex]::Escape($module))
            }
        }

        It 'applies the repository root from a working directory elsewhere' {
            # The repository copy contains a space, and the working directory of
            # the run is outside the repository.
            $chezmoiCalls = Get-FakeInvocation -LogPath $chezmoiLog
            $chezmoiCalls | Should -HaveCount 1
            $chezmoiCalls[0] | Should -Match 'init'
            $chezmoiCalls[0] | Should -Match '--apply'
            $chezmoiCalls[0] | Should -Match ([regex]::Escape('--source'))
            $chezmoiCalls[0] | Should -Match ([regex]::Escape($sandbox.Repo))
        }
    }

    Context 'a repeated run' {

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

        It 'installs nothing and adds no bucket the second time' {
            $first.ExitCode | Should -Be 0
            $second.ExitCode | Should -Be 0
            $callsAfterFirst | Should -BeGreaterThan 0
            $callsAfterSecond | Should -Be $callsAfterFirst
            $second.StdOut | Should -Match 'already installed'
        }

        It 'issues the same single chezmoi command per run' {
            $chezmoiCalls = Get-FakeInvocation -LogPath $chezmoiLog
            $chezmoiCalls | Should -HaveCount 2
            $chezmoiCalls[1] | Should -Be $chezmoiCalls[0]
        }
    }

    Context 'skip switches' {

        BeforeEach {
            $sandbox = New-Sandbox
            $scoopLog = New-FakeScoop -Directory $sandbox.Bin -ScoopRoot $sandbox.Scoop
            $chezmoiLog = New-FakeExecutable -Directory $sandbox.Bin -Name 'chezmoi'
            New-FakePwsh -Sandbox $sandbox | Out-Null
        }

        AfterEach {
            Remove-Sandbox -Sandbox $sandbox
        }

        It '-SkipPackages installs nothing but still applies the dotfiles' {
            $result = Invoke-InstallScript -Sandbox $sandbox -Arguments @('-SkipPackages')

            $result.ExitCode | Should -Be 0
            $result.StdOut | Should -Match 'Package bootstrap skipped'
            (Get-FakeInvocation -LogPath $scoopLog).Count | Should -Be 0
            (Get-FakeInvocation -LogPath $chezmoiLog) | Should -HaveCount 1
        }

        It '-SkipOptional installs the required packages only' {
            $result = Invoke-InstallScript -Sandbox $sandbox -Arguments @('-SkipOptional')

            $result.ExitCode | Should -Be 0
            $result.StdOut | Should -Match 'Optional CLI and TUI packages skipped'
            $installed = Get-ScoopCall -LogPath $scoopLog -Verb 'install'
            foreach ($name in $optionalNames) {
                $installed | Should -Not -Contain $name
            }
            $installed.Count | Should -BeGreaterThan 0
        }
    }

    Context 'failure policy' {

        BeforeEach {
            $sandbox = New-Sandbox
            New-FakePwsh -Sandbox $sandbox | Out-Null
        }

        AfterEach {
            Remove-Sandbox -Sandbox $sandbox
        }

        It 'fails and names the package when a required package cannot be installed' {
            New-FakeExecutable -Directory $sandbox.Bin -Name 'chezmoi' | Out-Null
            $failing = $requiredNames | Where-Object { @('chezmoi', 'pwsh') -notcontains $_ } |
                Select-Object -First 1
            $scoopLog = New-FakeScoop -Directory $sandbox.Bin -ScoopRoot $sandbox.Scoop -FailPattern $failing

            $result = Invoke-InstallScript -Sandbox $sandbox

            $result.ExitCode | Should -Not -Be 0
            $result.StdOut | Should -Match "required failures: .*$failing"
            $result.StdErr | Should -Match $failing
            $result.StdOut | Should -Not -Match 'Done, restart your shell'
            # The other packages are still attempted.
            (Get-ScoopCall -LogPath $scoopLog -Verb 'install').Count | Should -BeGreaterThan 1
        }

        It 'warns but succeeds when an optional package cannot be installed' {
            $chezmoiLog = New-FakeExecutable -Directory $sandbox.Bin -Name 'chezmoi'
            $failing = $optionalNames | Select-Object -First 1
            $scoopLog = New-FakeScoop -Directory $sandbox.Bin -ScoopRoot $sandbox.Scoop -FailPattern $failing

            $result = Invoke-InstallScript -Sandbox $sandbox

            $result.ExitCode | Should -Be 0
            $result.StdOut | Should -Match "optional failures: $failing"
            $result.StdOut | Should -Match 'Done, restart your shell'
            (Get-ScoopCall -LogPath $scoopLog -Verb 'install').Count | Should -BeGreaterThan 1
            (Get-FakeInvocation -LogPath $chezmoiLog) | Should -HaveCount 1
        }

        It 'propagates the exit code of chezmoi without a stack trace' {
            New-FakeExecutable -Directory $sandbox.Bin -Name 'chezmoi' -ExitCode 7 | Out-Null

            $result = Invoke-InstallScript -Sandbox $sandbox -Arguments @('-SkipPackages')

            $result.ExitCode | Should -Be 7
            $result.StdErr | Should -Match 'chezmoi exited with code 7'
            $result.StdErr | Should -Match 'chezmoi doctor'
            $result.StdErr | Should -Not -Match 'ScriptStackTrace'
            $result.StdOut | Should -Not -Match 'Done, restart your shell'
        }

        It 'fails when chezmoi is missing and cannot be installed' {
            $result = Invoke-InstallScript -Sandbox $sandbox -Arguments @('-SkipPackages')

            $result.ExitCode | Should -Not -Be 0
            $result.StdErr | Should -Match 'chezmoi was not found'
            $result.StdErr | Should -Match 'scoop install chezmoi'
            (Get-SandboxHomeEntry -Sandbox $sandbox).Count | Should -Be 0
        }

        It 'fails when the repository or the package list is incomplete' {
            New-FakeExecutable -Directory $sandbox.Bin -Name 'chezmoi' | Out-Null
            Remove-Item -LiteralPath (Join-Path $sandbox.Repo 'packages') -Recurse -Force

            $result = Invoke-InstallScript -Sandbox $sandbox

            $result.ExitCode | Should -Not -Be 0
            $result.StdErr | Should -Match ([regex]::Escape('windows.psd1'))
        }
    }

    Context 'Scoop is required infrastructure' {

        BeforeEach {
            $sandbox = New-Sandbox
            New-FakePwsh -Sandbox $sandbox | Out-Null
        }

        AfterEach {
            Remove-Sandbox -Sandbox $sandbox
        }

        It 'does not bootstrap Scoop when Scoop is already there' {
            New-FakeExecutable -Directory $sandbox.Bin -Name 'chezmoi' | Out-Null
            New-FakeScoop -Directory $sandbox.Bin -ScoopRoot $sandbox.Scoop | Out-Null

            $result = Invoke-InstallScript -Sandbox $sandbox

            $result.ExitCode | Should -Be 0
            $result.StdOut | Should -Not -Match 'downloading'
            $result.StdOut | Should -Match ([regex]::Escape($sandbox.Bin))
        }

        It 'aborts without installing or applying anything when the bootstrap fails' {
            # HTTPS_PROXY points at a closed port, so the download cannot succeed.
            $chezmoiLog = New-FakeExecutable -Directory $sandbox.Bin -Name 'chezmoi'

            $result = Invoke-InstallScript -Sandbox $sandbox

            $result.ExitCode | Should -Not -Be 0
            $result.StdOut | Should -Match 'Downloading the Scoop installer'
            $result.StdErr | Should -Match 'Scoop could not be bootstrapped'
            $result.StdErr | Should -Match ([regex]::Escape($sandbox.Scoop))
            $result.StdOut | Should -Not -Match 'Installing required packages'
            $result.StdOut | Should -Not -Match 'Applying dotfiles with chezmoi'
            (Get-FakeInvocation -LogPath $chezmoiLog).Count | Should -Be 0
            (Get-SandboxHomeEntry -Sandbox $sandbox).Count | Should -Be 0
        }

        It 'finds a Scoop shim that is not on PATH yet' {
            $shims = Join-Path $sandbox.Scoop 'shims'
            New-Item -ItemType Directory -Force -Path $shims | Out-Null
            $shimLog = New-FakeExecutable -Directory $shims -Name 'chezmoi'

            $result = Invoke-InstallScript -Sandbox $sandbox -Arguments @('-SkipPackages')

            $result.ExitCode | Should -Be 0
            (Get-FakeInvocation -LogPath $shimLog) | Should -HaveCount 1
        }
    }

    Context '-DryRun' {

        BeforeAll {
            $sandbox = New-Sandbox
            $chezmoiLog = New-FakeExecutable -Directory $sandbox.Bin -Name 'chezmoi'
            $pwshLog = New-FakePwsh -Sandbox $sandbox
            # No fake scoop: the plan has to cover the Scoop bootstrap as well.
            $result = Invoke-InstallScript -Sandbox $sandbox -Arguments @('-DryRun')
        }

        AfterAll {
            Remove-Sandbox -Sandbox $sandbox
        }

        It 'prints the plan for Scoop, the buckets and the packages' {
            $result.ExitCode | Should -Be 0
            $result.StdOut | Should -Match ([regex]::Escape('would bootstrap Scoop'))
            $result.StdOut | Should -Match ([regex]::Escape('https://get.scoop.sh'))
            $result.StdOut | Should -Match "would add bucket: $($packages.Buckets[0])"
            $result.StdOut | Should -Match 'would install with scoop:'
            $result.StdOut | Should -Match 'would install missing PowerShell modules'
            $result.StdOut | Should -Match 'Dry run complete'
        }

        It 'changes nothing' {
            (Get-FakeInvocation -LogPath $pwshLog).Count | Should -Be 0
            (Get-FakeInvocation -LogPath $chezmoiLog)[0] | Should -Match '--dry-run'
            (Get-SandboxHomeEntry -Sandbox $sandbox).Count | Should -Be 0
            Join-Path $sandbox.Scoop 'apps' | Should -Not -Exist
            Join-Path $sandbox.Scoop 'buckets' | Should -Not -Exist
        }
    }

    Context 'Windows PowerShell 5.1 contract' {

        BeforeAll {
            $installPath = Join-Path $RepoRoot 'install.ps1'
            $readmePath = Join-Path $RepoRoot 'README.md'
            $tokens = $null
            $errors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile(
                $installPath, [ref]$tokens, [ref]$errors)
            $bootstrapCommand = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1'
        }

        It 'parses and declares the minimum version' {
            @($errors) | Should -HaveCount 0
            Get-Content -LiteralPath $installPath -Raw | Should -Match '#Requires -Version 5\.1'
        }

        It 'uses no PowerShell 7 only language features' {
            # ?? and ??=, ?. and ?[ , ternary ? : , pipeline chains && and ||.
            $ps7Operators = @(
                'QuestionQuestion', 'QuestionQuestionEquals', 'QuestionDot',
                'QuestionLBracket', 'QuestionMark', 'AndAnd', 'OrOr'
            )
            @($tokens | Where-Object { $ps7Operators -contains $_.Kind.ToString() }) |
                Should -HaveCount 0

            $variables = @($tokens |
                    Where-Object { $_ -is [System.Management.Automation.Language.VariableToken] } |
                    ForEach-Object { $_.Name })
            foreach ($ps7Only in @('IsWindows', 'IsLinux', 'IsMacOS', 'IsCoreCLR')) {
                $variables | Should -Not -Contain $ps7Only
            }

            $commands = @($tokens |
                    Where-Object { $_.Kind.ToString() -eq 'Generic' } |
                    ForEach-Object { $_.Text })
            foreach ($ps7Only in @('Join-String', 'ConvertFrom-Markdown', 'Get-Uptime')) {
                $commands | Should -Not -Contain $ps7Only
            }
        }

        It 'is pure ASCII so Windows PowerShell reads it without a BOM' {
            @([IO.File]::ReadAllBytes($installPath) | Where-Object { $_ -gt 127 }) |
                Should -HaveCount 0
        }

        It 'documents Windows PowerShell 5.1 as the bootstrap entry point' {
            Get-Content -LiteralPath $installPath -Raw |
                Should -Match ([regex]::Escape($bootstrapCommand))
            Get-Content -LiteralPath $readmePath -Raw |
                Should -Match ([regex]::Escape($bootstrapCommand))
        }

        It 'needs no PowerShell 7 to start, only for the module step' {
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

        It 'keeps the package list the only place that names packages' {
            $literals = @($tokens |
                    Where-Object { $_ -is [System.Management.Automation.Language.StringToken] } |
                    ForEach-Object { $_.Value })
            $names = @($packages.Required | ForEach-Object { $_.Scoop }) +
            @($packages.Optional | ForEach-Object { $_.Scoop }) + @($packages.PSModules)
            # chezmoi and pwsh are commands install.ps1 drives itself.
            foreach ($name in $names) {
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

        It 'has no winget code path left' {
            foreach ($path in @($installPath, $readmePath,
                    (Join-Path $PSScriptRoot 'TestHelpers.ps1'))) {
                Get-Content -LiteralPath $path -Raw | Should -Not -Match 'winget'
            }
        }
    }
}
