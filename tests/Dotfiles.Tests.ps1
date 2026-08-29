<#
    Smoke tests for the dotfiles themselves.

    These tests never assert configuration values: changing a colour, a keymap
    or an alias must not require a change here. They only check that chezmoi can
    render and apply the source state and that the committed configuration files
    parse. Tools that are not installed are skipped instead of installed.
#>

#Requires -Version 5.1

. (Join-Path $PSScriptRoot 'TestHelpers.ps1')

Describe 'chezmoi source state' -Skip:(-not $RealChezmoi) {

    BeforeAll {
        . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
        $sandbox = New-Sandbox
        $apply = Invoke-SandboxChezmoi -Sandbox $sandbox -Arguments @(
            'init', '--apply', '--source', $sandbox.Repo)
        $verify = Invoke-SandboxChezmoi -Sandbox $sandbox -Arguments @('verify')
        $sourcePath = Invoke-SandboxChezmoi -Sandbox $sandbox -Arguments @('source-path')
        $managed = Invoke-SandboxChezmoi -Sandbox $sandbox -Arguments @('managed')
    }

    AfterAll {
        Remove-Sandbox -Sandbox $sandbox
    }

    It 'renders and applies into a temporary home' {
        $apply.ExitCode | Should -Be 0
        $apply.StdErr | Should -BeNullOrEmpty
    }

    It 'passes chezmoi verify after apply' {
        # chezmoi decides whether the target state matches, so this file does
        # not repeat any of chezmoi's own rules.
        $verify.ExitCode | Should -Be 0
    }

    It 'resolves the source root through .chezmoiroot' {
        $root = (Get-Content -LiteralPath (Join-Path $sandbox.Repo '.chezmoiroot') -Raw).Trim()
        $sourcePath.StdOut.Trim() | Should -Be (Join-Path $sandbox.Repo $root)
    }

    It 'manages files in the temporary home' {
        @($managed.StdOut -split "`n" | Where-Object { $_.Trim() }).Count |
            Should -BeGreaterThan 0
    }
}

Describe 'configuration files parse' {

    BeforeAll {
        . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
        $sourceHome = Join-Path $RepoRoot 'home'

        function Get-DotfilesPath {
            param([string]$Filter, [string]$SubPath = '.')

            return @(Get-ChildItem -Path (Join-Path $sourceHome $SubPath) -Filter $Filter -File -Recurse |
                    ForEach-Object { $_.FullName })
        }

        function Invoke-Tool {
            param([string]$FilePath, [string[]]$ToolArguments)

            $process = [Diagnostics.Process]::Start(
                (New-Object System.Diagnostics.ProcessStartInfo -Property @{
                        FileName               = $FilePath
                        Arguments              = ($ToolArguments | ForEach-Object {
                                $argument = $_ -replace '"', '\"'
                                if ($argument -match '\s') { '"' + $argument + '"' } else { $argument }
                            }) -join ' '
                        UseShellExecute        = $false
                        RedirectStandardOutput = $true
                        RedirectStandardError  = $true
                    }))
            $output = $process.StandardOutput.ReadToEnd() + $process.StandardError.ReadToEnd()
            $process.WaitForExit()

            return [pscustomobject]@{ ExitCode = $process.ExitCode; Output = $output }
        }

    }

    It 'parses every PowerShell file of the profile' {
        $failures = @()
        foreach ($path in (Get-DotfilesPath -Filter '*.ps1' -SubPath 'Documents')) {
            $errors = $null
            [System.Management.Automation.Language.Parser]::ParseFile(
                $path, [ref]$null, [ref]$errors) | Out-Null
            if (@($errors).Count) {
                $failures += "$path : $($errors[0].Message)"
            }
        }
        $failures | Should -HaveCount 0
    }

    It 'parses every committed JSON file' {
        $failures = @()
        foreach ($path in (Get-DotfilesPath -Filter '*.json')) {
            try {
                Get-Content -LiteralPath $path -Raw | ConvertFrom-Json | Out-Null
            }
            catch {
                $failures += "$path : $($_.Exception.Message)"
            }
        }
        $failures | Should -HaveCount 0
    }

    It 'parses the TOML configuration' -Skip:(-not $RealChezmoi) {
        # chezmoi ships a TOML parser, so no extra dependency is needed.
        foreach ($path in (Get-DotfilesPath -Filter '*.toml')) {
            # Backslashes are escape sequences inside a Go template string, and
            # Go accepts forward slashes on Windows too.
            $templatePath = $path -replace '\\', '/'
            $result = Invoke-Tool -FilePath $RealChezmoi -ToolArguments @(
                'execute-template', "{{ (include `"$templatePath`") | fromToml | len }}")
            $result.ExitCode | Should -Be 0 -Because "$path should be valid TOML: $($result.Output)"
        }
    }

    It 'parses the bash configuration' -Skip:(-not $RealBash) {
        $paths = @(
            Join-Path $sourceHome 'dot_bashrc'
            Join-Path $sourceHome 'dot_bash_profile'
        ) + (Get-DotfilesPath -Filter '*.bash')

        foreach ($path in $paths) {
            $result = Invoke-Tool -FilePath $RealBash -ToolArguments @('-n', $path)
            $result.ExitCode | Should -Be 0 -Because "bash -n $path said: $($result.Output)"
        }
    }

    It 'parses the fish configuration' -Skip:(-not $RealFish) {
        foreach ($path in (Get-DotfilesPath -Filter '*.fish')) {
            $result = Invoke-Tool -FilePath $RealFish -ToolArguments @('--no-execute', $path)
            $result.ExitCode | Should -Be 0 -Because "fish --no-execute $path said: $($result.Output)"
        }
    }

    It 'loads the tmux configuration' -Skip:(-not $RealTmux) {
        $config = Join-Path $sourceHome 'dot_config/tmux/tmux.conf'
        $result = Invoke-Tool -FilePath $RealTmux -ToolArguments @(
            '-f', $config, '-L', 'dotfiles-smoke', 'start-server', ';', 'kill-server')
        $result.ExitCode | Should -Be 0 -Because "tmux said: $($result.Output)"
    }
}
