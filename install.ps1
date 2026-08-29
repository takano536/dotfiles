<#
.SYNOPSIS
    Bootstraps a Windows machine from this chezmoi source repository.

.DESCRIPTION
    Ensures Scoop, the packages listed in packages\windows.psd1 and chezmoi are
    available, then runs 'chezmoi init --apply' with this repository as the
    chezmoi source directory. Safe to run repeatedly.

    Required packages are needed for the applied dotfiles to work; a failure
    makes the whole run fail. Optional packages are everyday CLI and TUI tools;
    a failure is reported as a warning and the run continues. AI coding agents,
    Docker, WSL, GUI applications, fonts and credentials are never installed.

.PARAMETER DryRun
    Print the install plan without installing packages or changing the home
    directory.

.PARAMETER SkipPackages
    Do not bootstrap Scoop or any package except chezmoi itself.

.PARAMETER SkipOptional
    Install the required packages but not the optional CLI and TUI tools.

.PARAMETER SkipChezmoiInstall
    Fail instead of installing chezmoi when it is not found.

.EXAMPLE
    .\install.ps1

.EXAMPLE
    .\install.ps1 -DryRun

.EXAMPLE
    .\install.ps1 -SkipOptional -Verbose
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$SkipPackages,
    [switch]$SkipOptional,
    [switch]$SkipChezmoiInstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

##### Run state, reported by the summary #####
$script:Planned = @()
$script:Installed = @()
$script:Present = @()
$script:RequiredFailures = @()
$script:OptionalFailures = @()
$script:Notes = @()

function Write-Step {
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Message
    )

    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Add-Note {
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Message
    )

    Write-Host "    $Message"
    $script:Notes += $Message
}

function Find-Executable {
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name
    )

    # The Scoop shim is preferred: this repository pins Scoop paths (Windows
    # Terminal starts Scoop's pwsh), a shim created a moment ago is not in the
    # PATH of this process yet, and PowerShell puts its own $PSHOME in front of
    # PATH, which would otherwise shadow the Scoop-managed pwsh.
    if ($script:ScoopRoot) {
        $shims = Join-Path $script:ScoopRoot 'shims'
        foreach ($candidate in @("$Name.exe", "$Name.cmd", $Name)) {
            $shim = Join-Path $shims $candidate
            if (Test-Path -LiteralPath $shim -PathType Leaf) {
                return $shim
            }
        }
    }

    $command = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($command) {
        return $command.Source
    }

    return $null
}

function Test-PackageInstalled {
    param(
        [Parameter(Mandatory, Position = 0)]
        [hashtable]$Package
    )

    # Scoop keeps every app in <root>\apps\<name>\current. Checking that is
    # more reliable than PATH, because manifests such as starship and gcc
    # create no shim and a fresh shim is not in the PATH of this process.
    foreach ($root in @($script:ScoopRoot, $env:SCOOP_GLOBAL)) {
        if ($root) {
            $appDir = Join-Path (Join-Path $root 'apps') (Join-Path $Package.Scoop 'current')
            if (Test-Path -LiteralPath $appDir) {
                return $true
            }
        }
    }

    return [bool](Find-Executable $Package.Command)
}

function Install-Scoop {
    <#
        Installs Scoop into $script:ScoopRoot with the official installer from
        https://get.scoop.sh, which is the download endpoint of the Scoop
        project's own ScoopInstaller/Install repository and the only documented
        way to bootstrap Scoop. The script is downloaded to a file, checked for
        the expected -ScoopDir parameter and then executed, instead of piping a
        web response straight into Invoke-Expression. No elevation is used, so
        Scoop installs per user.
    #>

    $installerUri = 'https://get.scoop.sh'
    $installerPath = Join-Path ([IO.Path]::GetTempPath()) 'install-scoop.ps1'

    if ($DryRun) {
        Write-Host "    would download $installerUri and install Scoop into $script:ScoopRoot"
        return $false
    }

    # Windows PowerShell 5.1 still negotiates TLS 1.0 on older systems.
    try {
        [Net.ServicePointManager]::SecurityProtocol =
        [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    }
    catch {
        Write-Verbose "Could not raise the TLS version: $($_.Exception.Message)"
    }

    $requestArgs = @{
        Uri             = $installerUri
        OutFile         = $installerPath
        UseBasicParsing = $true
    }
    if ($env:HTTPS_PROXY) {
        $requestArgs['Proxy'] = $env:HTTPS_PROXY
    }

    Write-Host "    downloading $installerUri"
    try {
        Invoke-WebRequest @requestArgs
    }
    catch {
        Add-Note "Downloading the Scoop installer from $installerUri failed: $($_.Exception.Message). Check the network and HTTPS_PROXY, or install Scoop manually from https://scoop.sh."
        return $false
    }

    # A proxy error page must not be executed as the installer.
    if ((Get-Content -LiteralPath $installerPath -Raw) -notmatch 'ScoopDir') {
        Add-Note "The file downloaded from $installerUri is not the Scoop installer (no -ScoopDir parameter). Inspect '$installerPath' and install Scoop manually."
        return $false
    }

    Write-Host "    installing Scoop into $script:ScoopRoot"
    $installerArgs = @('-ScoopDir', $script:ScoopRoot)
    if ($env:HTTPS_PROXY) {
        $installerArgs += @('-Proxy', $env:HTTPS_PROXY)
    }
    try {
        & $installerPath @installerArgs
    }
    catch {
        Add-Note "The Scoop installer failed: $($_.Exception.Message). Install Scoop manually from https://scoop.sh and re-run install.ps1."
        return $false
    }

    # The installer updates the PATH of the user, not of this process.
    $env:SCOOP = $script:ScoopRoot
    $env:PATH = (Join-Path $script:ScoopRoot 'shims') + [IO.Path]::PathSeparator + $env:PATH

    return $true
}

function Add-ScoopBucket {
    param(
        [Parameter(Mandatory, Position = 0)]
        [string[]]$Bucket
    )

    foreach ($name in $Bucket) {
        if (Test-Path -LiteralPath (Join-Path (Join-Path $script:ScoopRoot 'buckets') $name)) {
            Write-Host "    bucket present: $name"
            continue
        }

        if ($DryRun) {
            Write-Host "    would add bucket: $name"
            continue
        }

        Write-Host "    adding bucket: $name"
        & $script:ScoopPath bucket add $name
        if ($LASTEXITCODE -ne 0) {
            Add-Note "'scoop bucket add $name' failed with exit code $LASTEXITCODE; packages from that bucket cannot be installed."
        }
    }
}

function Install-BootstrapPackage {
    <#
        Installs one package entry from packages\windows.psd1 and returns
        whether the package is available afterwards.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [hashtable]$Package
    )

    $name = $Package.Scoop

    if (Test-PackageInstalled $Package) {
        Write-Host "    present: $name"
        $script:Present += $name
        return $true
    }

    if ($DryRun) {
        # Scoop is bootstrapped before packages are installed, so scoop is the
        # manager that a real run would try first.
        $manager = 'scoop'
        if (-not $script:ScoopPath -and $script:WingetPath -and $Package.ContainsKey('Winget')) {
            $manager = 'winget'
        }
        Write-Host "    would install with ${manager}: $name"
        $script:Planned += $name
        return $true
    }

    if ($script:ScoopPath) {

        Write-Host "    scoop install $name"
        & $script:ScoopPath install $name
        if ($LASTEXITCODE -eq 0) {
            $script:Installed += $name
            return $true
        }

        Write-Host "    failed: 'scoop install $name' exited with code $LASTEXITCODE"
        return $false
    }

    if ($script:WingetPath -and $Package.ContainsKey('Winget')) {

        Write-Host "    winget install $($Package.Winget)"
        & $script:WingetPath install --exact --id $Package.Winget `
            --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -eq 0) {
            $script:Installed += $name
            return $true
        }

        Write-Host "    failed: 'winget install $($Package.Winget)' exited with code $LASTEXITCODE"
        return $false
    }

    Write-Host "    failed: no package manager available for $name"
    return $false
}

function Install-PSModule {
    <#
        Installs the modules that Documents\PowerShell\Profile\modules.ps1
        imports. They have to land in the module path of PowerShell 7, so they
        are installed by pwsh even when install.ps1 runs in Windows PowerShell.
        Already installed modules are skipped by the inner script.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string[]]$Name
    )

    $pwshPath = Find-Executable 'pwsh'
    if (-not $pwshPath) {
        Add-Note "PowerShell 7 was not found, so the modules $($Name -join ', ') were not installed. Re-run install.ps1 after pwsh is available."
        return
    }

    if ($DryRun) {
        Write-Host "    would install missing PowerShell modules with pwsh: $($Name -join ', ')"
        return
    }

    $quoted = ($Name | ForEach-Object { "'$_'" }) -join ', '
    $command = @"
`$ErrorActionPreference = 'Stop'
foreach (`$name in @($quoted)) {
    if (Get-Module -ListAvailable -Name `$name) { continue }
    Write-Host "    Install-Module `$name"
    Install-Module -Name `$name -Scope CurrentUser -Force
}
"@

    Write-Host "    checking PowerShell modules: $($Name -join ', ')"
    & $pwshPath -NoLogo -NoProfile -NonInteractive -Command $command
    if ($LASTEXITCODE -ne 0) {
        Add-Note "Installing the PowerShell modules $($Name -join ', ') failed with exit code $LASTEXITCODE; 'Install-Module <name> -Scope CurrentUser' in pwsh installs them manually."
    }
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

    $packageFile = Join-Path (Join-Path $repoRoot 'packages') 'windows.psd1'
    if (-not (Test-Path -LiteralPath $packageFile -PathType Leaf)) {
        throw "The package list '$packageFile' was not found. Check out the repository again, or use -SkipPackages to only apply the dotfiles."
    }
    $packages = Import-PowerShellDataFile -LiteralPath $packageFile

    # Documents\PowerShell\Profile\env.ps1 points $env:SCOOP here, so Scoop has
    # to use the same root.
    $script:ScoopRoot = $env:SCOOP
    if (-not $script:ScoopRoot) {
        $script:ScoopRoot = Join-Path $env:LOCALAPPDATA 'Programs\Scoop'
    }

    ##### Prerequisites #####
    Write-Step 'Checking prerequisites'
    Write-Host "    host:      PowerShell $($PSVersionTable.PSVersion) on $([Environment]::OSVersion.VersionString)"
    Write-Host "    source:    $sourceDir"
    Write-Host "    scoop dir: $script:ScoopRoot"
    if ($DryRun) {
        Write-Host '    dry run: nothing is installed and the home directory is not changed'
    }

    $script:ScoopPath = Find-Executable 'scoop'
    $script:WingetPath = Find-Executable 'winget'

    ##### Packages #####
    if ($SkipPackages) {
        Add-Note 'Package bootstrap skipped (-SkipPackages).'
    }
    else {
        Write-Step 'Ensuring Scoop'
        if ($script:ScoopPath) {
            Write-Host "    scoop: $script:ScoopPath"
        }
        else {
            if (Install-Scoop) {
                $script:ScoopPath = Find-Executable 'scoop'
            }
            if (-not $script:ScoopPath -and -not $DryRun) {
                Add-Note 'Scoop is not available; packages with a winget id are installed with winget instead.'
            }
        }

        if ($script:ScoopPath -or $DryRun) {
            Write-Step 'Ensuring Scoop buckets'
            Add-ScoopBucket $packages.Buckets
        }

        Write-Step 'Installing required packages'
        foreach ($package in $packages.Required) {
            if (-not (Install-BootstrapPackage $package)) {
                $script:RequiredFailures += $package.Scoop
            }
        }

        if ($SkipOptional) {
            Add-Note 'Optional CLI and TUI packages skipped (-SkipOptional).'
        }
        else {
            Write-Step 'Installing optional CLI and TUI packages'
            foreach ($package in $packages.Optional) {
                if (-not (Install-BootstrapPackage $package)) {
                    $script:OptionalFailures += $package.Scoop
                }
            }
        }

        Write-Step 'Installing PowerShell modules'
        Install-PSModule $packages.PSModules
    }

    ##### chezmoi #####
    Write-Step 'Checking chezmoi'
    $chezmoi = Find-Executable 'chezmoi'
    if (-not $chezmoi) {
        if ($SkipChezmoiInstall) {
            throw "chezmoi was not found on PATH and -SkipChezmoiInstall was specified. Install chezmoi with 'scoop install chezmoi' or 'winget install twpayne.chezmoi', then re-run install.ps1."
        }

        $chezmoiPackage = $packages.Required | Where-Object { $_.Command -eq 'chezmoi' } | Select-Object -First 1
        if (-not (Install-BootstrapPackage $chezmoiPackage)) {
            throw "chezmoi was not found and could not be installed. Install it with 'scoop install chezmoi', 'winget install twpayne.chezmoi', or see https://www.chezmoi.io/install/, then re-run install.ps1."
        }

        $chezmoi = Find-Executable 'chezmoi'
        if (-not $chezmoi -and -not $DryRun) {
            throw "chezmoi is still not on PATH after installation. Open a new shell so PATH is refreshed, then re-run install.ps1."
        }
    }
    if ($chezmoi) {
        Write-Host "    chezmoi: $chezmoi"
    }

    ##### Apply #####
    if ($chezmoi) {
        Write-Step 'Applying dotfiles with chezmoi'

        # 'init' writes the chezmoi config file from home\.chezmoi.toml.tmpl so
        # that plain 'chezmoi apply' keeps using this repository; '--apply'
        # updates the home directory. Both steps are idempotent.
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
    }

    ##### Summary #####
    Write-Step 'Summary'
    if ($script:Planned.Count) {
        Write-Host "    would install:     $($script:Planned -join ', ')"
    }
    if ($script:Installed.Count) {
        Write-Host "    installed:         $($script:Installed -join ', ')"
    }
    if ($script:Present.Count) {
        Write-Host "    already installed: $($script:Present -join ', ')"
    }
    if ($script:OptionalFailures.Count) {
        Write-Host "    optional failures: $($script:OptionalFailures -join ', ')" -ForegroundColor Yellow
        Write-Host '    re-run install.ps1 or install those packages manually with scoop'
    }
    if ($script:RequiredFailures.Count) {
        Write-Host "    required failures: $($script:RequiredFailures -join ', ')" -ForegroundColor Red
    }

    if ($script:RequiredFailures.Count) {
        $host.UI.WriteErrorLine("install.ps1: the required packages $($script:RequiredFailures -join ', ') could not be installed. Read the package manager output above, then re-run install.ps1.")
        exit 1
    }

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
