<#
.SYNOPSIS
    Applies this chezmoi source repository to the current user's home directory.

.DESCRIPTION
    Checks the prerequisites (git, chezmoi), installs chezmoi with Scoop or
    winget if it is missing, and then runs 'chezmoi init --apply' with this
    repository as the chezmoi source directory. Safe to run repeatedly.

.PARAMETER DryRun
    Show what chezmoi would change without modifying the home directory.

.PARAMETER SkipChezmoiInstall
    Fail instead of installing chezmoi when it is not found.

.EXAMPLE
    .\install.ps1

.EXAMPLE
    .\install.ps1 -DryRun -Verbose
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$SkipChezmoiInstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Step {
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Message
    )

    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Find-Executable {
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name
    )

    $command = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($command) {
        return $command.Source
    }

    # Scoop shims are not on PATH yet in the shell that installed them.
    if ($env:SCOOP) {
        $shim = Join-Path (Join-Path $env:SCOOP 'shims') "$Name.exe"
        if (Test-Path -LiteralPath $shim -PathType Leaf) {
            return $shim
        }
    }

    return $null
}

function Install-Chezmoi {
    $scoop = Find-Executable 'scoop'
    if ($scoop) {
        Write-Host "    scoop install chezmoi"
        & $scoop install chezmoi
        if ($LASTEXITCODE -eq 0) {
            return
        }
        throw "'scoop install chezmoi' failed with exit code $LASTEXITCODE. Check the scoop output above, or install chezmoi manually."
    }

    $winget = Find-Executable 'winget'
    if ($winget) {
        Write-Host "    winget install twpayne.chezmoi"
        & $winget install --exact --id twpayne.chezmoi --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -eq 0) {
            return
        }
        throw "'winget install twpayne.chezmoi' failed with exit code $LASTEXITCODE. Check the winget output above, or install chezmoi manually."
    }

    throw "chezmoi was not found and neither scoop nor winget is available. Install chezmoi with 'scoop install chezmoi', 'winget install twpayne.chezmoi', or see https://www.chezmoi.io/install/, then re-run install.ps1."
}

try {
    ##### Repository #####
    $repoRoot = $PSScriptRoot
    $chezmoiRootFile = Join-Path $repoRoot '.chezmoiroot'
    if (-not (Test-Path -LiteralPath $chezmoiRootFile -PathType Leaf)) {
        throw "'$chezmoiRootFile' was not found, so '$repoRoot' is not this dotfiles repository. Run install.ps1 from the repository it was cloned into."
    }

    $sourceDir = Join-Path $repoRoot ((Get-Content -LiteralPath $chezmoiRootFile -Raw).Trim())
    if (-not (Test-Path -LiteralPath $sourceDir -PathType Container)) {
        throw "The chezmoi source directory '$sourceDir' referenced by .chezmoiroot is missing. Check out the repository again."
    }

    ##### Prerequisites #####
    Write-Step 'Checking prerequisites'

    $git = Find-Executable 'git'
    if (-not $git) {
        throw "git was not found on PATH. chezmoi uses git for this source repository. Install it with 'scoop install git' or 'winget install Git.Git', then re-run install.ps1."
    }
    Write-Host "    git:     $git"

    $chezmoi = Find-Executable 'chezmoi'
    if (-not $chezmoi) {
        if ($SkipChezmoiInstall) {
            throw "chezmoi was not found on PATH and -SkipChezmoiInstall was specified. Install chezmoi with 'scoop install chezmoi' or 'winget install twpayne.chezmoi', then re-run install.ps1."
        }

        Write-Step 'Installing chezmoi'
        Install-Chezmoi

        $chezmoi = Find-Executable 'chezmoi'
        if (-not $chezmoi) {
            throw "chezmoi is still not on PATH after installation. Open a new shell so PATH is refreshed, then re-run install.ps1."
        }
    }
    Write-Host "    chezmoi: $chezmoi"
    Write-Host "    source:  $sourceDir"

    ##### Apply #####
    Write-Step 'Applying dotfiles with chezmoi'

    # 'init' writes the chezmoi config file from home/.chezmoi.toml.tmpl so that
    # plain 'chezmoi apply' keeps using this repository; '--apply' updates the
    # home directory. Both steps are idempotent.
    $chezmoiArgs = @('init', '--apply', '--source', $repoRoot)
    if ($DryRun) {
        $chezmoiArgs += '--dry-run'
    }
    if ($VerbosePreference -ne 'SilentlyContinue') {
        $chezmoiArgs += '--verbose'
    }

    Write-Host "    chezmoi $($chezmoiArgs -join ' ')"
    & $chezmoi @chezmoiArgs
    if ($LASTEXITCODE -ne 0) {
        $host.UI.WriteErrorLine("install.ps1: chezmoi exited with code $LASTEXITCODE. Read the chezmoi output above; 'chezmoi diff' shows the pending changes and 'chezmoi doctor' checks the installation.")
        exit $LASTEXITCODE
    }

    ##### Done #####
    if ($DryRun) {
        Write-Step 'Dry run complete, the home directory was not changed'
    }
    else {
        Write-Step 'Done, restart your shell to pick up the new profile'
    }
}
catch {
    $host.UI.WriteErrorLine("install.ps1: $($_.Exception.Message)")
    exit 1
}
