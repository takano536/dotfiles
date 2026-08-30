<#
.SYNOPSIS
    Bootstraps a Windows machine from this chezmoi source repository.

.DESCRIPTION
    Ensures Scoop, the packages listed in packages\windows.psd1 and chezmoi are
    available, then runs 'chezmoi init --apply' with the repository as the
    chezmoi source directory. Safe to run repeatedly.

    It works in two modes and decides which one applies on its own:

    - repository-local: started from a checkout, recognised by the .chezmoiroot
      file next to it. That checkout is used as it is and nothing is cloned.
    - bootstrap: started on its own, for example downloaded to the temporary
      directory of the user. The repository is then cloned into chezmoi's
      source directory and the install.ps1 of the clone takes over the rest of
      the run.

    The entry point is Windows PowerShell 5.1, which every Windows installation
    ships:

        powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1

    PowerShell 7 is installed on the way as a package, not required to start.
    Only the steps that genuinely need it, such as installing modules into the
    module path of PowerShell 7, call the installed pwsh as a child process.

    Scoop is the only package manager: this repository pins Scoop's install
    layout (Windows Terminal starts %LOCALAPPDATA%\Programs\Scoop\apps\pwsh and
    ...\apps\git), so a run that cannot get Scoop fails instead of installing
    the same tools from somewhere else. A bootstrap run uses it for git as
    well, which it needs before it can read the package list.

    Required packages are needed for the applied dotfiles to work; a failure
    makes the whole run fail. Optional packages are everyday CLI and TUI tools;
    a failure is reported as a warning and the run continues. AI coding agents,
    Docker, WSL, GUI applications, fonts and credentials are never installed.

    No step needs Administrator rights.

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
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1

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

##### The repository this installer belongs to #####
# An existing checkout is matched on owner and repository name; the host is
# compared separately, because the same repository is cloned over HTTPS, over
# SSH or through an ssh_config alias whose real host cannot be resolved from
# the URL.
$script:RepoSlug = 'takano536/dotfiles'
$script:RepoHost = 'github.com'
$script:RepoUrl = 'https://github.com/takano536/dotfiles.git'
$script:RepoBranch = 'main'

# A bootstrap run has to clone before it can read packages\windows.psd1, so git
# is named here as well. It is a required package in that list too.
$script:GitPackage = 'git'

# Set for the installer of a fresh clone, so that a clone which still does not
# look like this repository fails instead of cloning again.
$script:BootstrapMarker = 'DOTFILES_BOOTSTRAP'

# The switches of this run, so that a bootstrap can hand them to the installer
# of the clone.
$script:ForwardedArguments = @($PSBoundParameters.Keys |
    Where-Object { $PSBoundParameters[$_] -is [switch] -and $PSBoundParameters[$_].IsPresent } |
    ForEach-Object { "-$_" })

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
        Installs one package entry from packages\windows.psd1 with Scoop and
        returns whether the package is available afterwards.
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
        Write-Host "    would install with scoop: $name"
        $script:Planned += $name
        return $true
    }

    if (-not $script:ScoopPath) {
        Write-Host "    failed: scoop is not available, cannot install $name"
        return $false
    }

    Write-Host "    scoop install $name"
    & $script:ScoopPath install $name
    if ($LASTEXITCODE -eq 0) {
        $script:Installed += $name
        return $true
    }

    Write-Host "    failed: 'scoop install $name' exited with code $LASTEXITCODE"
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

    # One line, because a command line with embedded newlines does not survive
    # every Windows shell that may sit between here and pwsh.
    $quoted = ($Name | ForEach-Object { "'$_'" }) -join ', '
    $command = "`$ErrorActionPreference = 'Stop'; " +
    "foreach (`$name in @($quoted)) { " +
    "if (Get-Module -ListAvailable -Name `$name) { continue }; " +
    "Install-Module -Name `$name -Scope CurrentUser -Force }"

    Write-Host "    checking PowerShell modules: $($Name -join ', ')"
    & $pwshPath -NoLogo -NoProfile -NonInteractive -Command $command
    if ($LASTEXITCODE -ne 0) {
        Add-Note "Installing the PowerShell modules $($Name -join ', ') failed with exit code $LASTEXITCODE; 'Install-Module <name> -Scope CurrentUser' in pwsh installs them manually."
    }
}

##### Repository acquisition #####

function Test-RepositoryMarker {
    <#
        .chezmoiroot is the marker of this repository. A checkout that has it
        but is missing other files is still this repository, and it has to fail
        with that problem instead of being replaced by a fresh clone somewhere
        else.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path
    )

    return (Test-Path -LiteralPath (Join-Path $Path '.chezmoiroot') -PathType Leaf)
}

function Test-CompleteRepository {
    <#
        What a freshly cloned or adopted checkout has to provide before this run
        hands over to it.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path
    )

    if (-not (Test-RepositoryMarker $Path)) {
        return $false
    }
    if (-not (Test-Path -LiteralPath (Join-Path $Path 'install.ps1') -PathType Leaf)) {
        return $false
    }

    $packageFile = Join-Path (Join-Path $Path 'packages') 'windows.psd1'
    return (Test-Path -LiteralPath $packageFile -PathType Leaf)
}

function Get-RemoteSlug {
    <#
        'owner/repo', lower cased, from any of the URL forms git understands, so
        that an existing checkout of this repository is recognised without
        insisting on the exact URL it was cloned with.
    #>
    param(
        [Parameter(Position = 0)]
        [string]$Url
    )

    if (-not $Url) {
        return ''
    }

    $trimmed = $Url.Trim().TrimEnd('/')
    if ($trimmed.EndsWith('.git')) {
        $trimmed = $trimmed.Substring(0, $trimmed.Length - 4)
    }

    # The owner is separated from the host by '/' in HTTPS URLs and by ':' in
    # SSH URLs, so both are accepted here.
    $parts = @($trimmed -split '[/:]' | Where-Object { $_ })
    if ($parts.Count -lt 2) {
        return ''
    }

    return ($parts[-2] + '/' + $parts[-1]).ToLowerInvariant()
}

function Get-RemoteHost {
    <#
        The host of a remote URL, lower cased: 'https://host/owner/repo',
        'ssh://git@host/owner/repo' and 'git@host:owner/repo' all resolve to
        'host'. An ssh_config alias resolves to the alias, which is exactly what
        cannot be checked without reading the SSH configuration.
    #>
    param(
        [Parameter(Position = 0)]
        [string]$Url
    )

    if (-not $Url) {
        return ''
    }

    $rest = $Url.Trim()
    $scheme = $rest.IndexOf('://')
    if ($scheme -ge 0) {
        $rest = $rest.Substring($scheme + 3)
    }
    $credentials = $rest.IndexOf('@')
    if ($credentials -ge 0) {
        $rest = $rest.Substring($credentials + 1)
    }
    $separator = $rest.IndexOfAny([char[]]@(':', '/'))
    if ($separator -ge 0) {
        $rest = $rest.Substring(0, $separator)
    }

    return $rest.ToLowerInvariant()
}

function Get-DefaultSourceRoot {
    <#
        Where a bootstrap run puts the repository: chezmoi's own default source
        directory, so that 'chezmoi apply' and 'chezmoi update' keep working
        without any extra configuration afterwards.
    #>

    $profileDir = $env:USERPROFILE
    if (-not $profileDir) {
        $profileDir = $env:HOME
    }
    if (-not $profileDir) {
        throw 'Neither USERPROFILE nor HOME is set, so the chezmoi source directory cannot be determined. Clone the repository yourself and run its install.ps1.'
    }

    return Join-Path (Join-Path (Join-Path $profileDir '.local') 'share') 'chezmoi'
}

function Invoke-Git {
    <#
        Runs git and returns its output as text, with the exit code in
        $script:GitExitCode. Native stderr is folded into the output, and
        $ErrorActionPreference is lowered for this function only, so that a
        query about a directory that is not a checkout is answered by the exit
        code instead of throwing in Windows PowerShell.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$GitPath,

        # An array, not remaining arguments: '-C' would otherwise be bound as a
        # parameter name of this function.
        [Parameter(Mandatory, Position = 1)]
        [string[]]$Arguments
    )

    $ErrorActionPreference = 'Continue'

    $output = & $GitPath @Arguments 2>&1
    $script:GitExitCode = $LASTEXITCODE
    return (@($output) -join "`n").Trim()
}

function Install-Git {
    <#
        git is one of the required packages, but a bootstrap run needs it before
        it can read the package list, so it is installed from here with the same
        package manager the rest of the run uses.
    #>

    if (Find-Executable 'git') {
        return
    }

    if ($SkipPackages) {
        throw "git is needed to clone $script:RepoUrl, but -SkipPackages was specified. Install git ('scoop install git'), or clone the repository yourself and run its install.ps1 -SkipPackages."
    }

    if (-not $script:ScoopPath) {
        Write-Host '    git is not installed, bootstrapping Scoop first'
        if (Install-Scoop) {
            $script:ScoopPath = Find-Executable 'scoop'
        }
        if (-not $script:ScoopPath) {
            throw "Scoop could not be bootstrapped into '$script:ScoopRoot', so git cannot be installed and $script:RepoUrl cannot be cloned. Install Scoop manually (see https://scoop.sh) or clone the repository yourself, then re-run install.ps1."
        }
    }

    Write-Host "    scoop install $script:GitPackage"
    & $script:ScoopPath install $script:GitPackage
    if ($LASTEXITCODE -ne 0) {
        throw "'scoop install $script:GitPackage' failed with exit code $LASTEXITCODE, so $script:RepoUrl cannot be cloned. Read the output above, or clone the repository yourself and run its install.ps1."
    }
    if (-not (Find-Executable 'git')) {
        throw "git is still not callable after the installation, so $script:RepoUrl cannot be cloned. Nothing else was changed."
    }
}

function Test-AdoptableCheckout {
    <#
        A directory that is already there is never deleted, moved or reset: it
        may be the user's own checkout with unpushed work. Returns $true when it
        can be used as it is, $false when it is empty and can be cloned into,
        and throws in every other case, with the way out in the message.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "'$Path' exists but is not a directory, so the dotfiles cannot be cloned there. Move it aside, or clone the repository yourself and run its install.ps1."
    }

    if (@(Get-ChildItem -LiteralPath $Path -Force).Count -eq 0) {
        return $false
    }

    if (-not (Test-CompleteRepository $Path)) {
        throw "'$Path' already exists and does not contain this dotfiles repository (.chezmoiroot, install.ps1 and packages\windows.psd1). Nothing was changed. Inspect it, then move it aside and re-run, or run install.ps1 from your own checkout."
    }

    $git = Find-Executable 'git'
    if (-not $git) {
        # Without git the checkout cannot be verified, but its layout already
        # matches; the run continues and reports that it could not check.
        Add-Note "The checkout in $Path was not verified because git is not installed yet."
        return $true
    }

    Invoke-Git $git @('-C', $Path, 'rev-parse', '--git-dir') | Out-Null
    if ($script:GitExitCode -ne 0) {
        throw "'$Path' contains the dotfiles but is not a git repository, so it cannot be updated later. Move it aside and re-run to get a clone, or run install.ps1 from your own checkout."
    }

    $origin = Invoke-Git $git @('-C', $Path, 'remote', 'get-url', 'origin')
    if ($script:GitExitCode -ne 0) {
        $origin = ''
    }
    if ((Get-RemoteSlug $origin) -ne $script:RepoSlug) {
        $reported = $origin
        if (-not $reported) {
            $reported = 'an unknown remote'
        }
        throw "'$Path' is a checkout of '$reported', not of $script:RepoSlug. Nothing was changed. Point 'origin' at $script:RepoUrl, or move that directory aside and re-run."
    }

    Write-Host "    using the existing checkout in $Path"

    # Nothing is fetched or reset here, so a host that only looks like the
    # expected one cannot change the checkout; it is reported instead of
    # resolving the SSH configuration to find out what the alias points at.
    $remoteHost = Get-RemoteHost $origin
    if ($remoteHost -ne $script:RepoHost) {
        Add-Note "The origin of $Path is '$origin', which names $script:RepoSlug but not $script:RepoHost; it is used as it is, on the assumption that '$remoteHost' is an ssh_config alias for $script:RepoHost."
    }
    $changes = Invoke-Git $git @('-C', $Path, 'status', '--porcelain')
    if ($script:GitExitCode -eq 0 -and $changes) {
        Add-Note "The checkout in $Path has uncommitted changes; nothing was pulled and they were left untouched."
    }

    return $true
}

function Invoke-GitClone {
    <#
        Cloned into a private temporary directory next to the target and moved
        into place afterwards, so an interrupted clone leaves nothing behind at
        the target and an existing directory is never overwritten.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Target
    )

    $git = Find-Executable 'git'
    $parent = Split-Path -Parent $Target
    New-Item -ItemType Directory -Force -Path $parent | Out-Null

    $temporary = Join-Path $parent ('.dotfiles-clone-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    $clone = Join-Path $temporary 'repo'

    # git must not ask for credentials: this is a public repository over HTTPS,
    # and a bootstrap run may have no console to ask on.
    $env:GIT_TERMINAL_PROMPT = '0'

    try {
        Write-Host "    git clone $script:RepoUrl (branch $script:RepoBranch)"
        & $git clone --branch $script:RepoBranch -- $script:RepoUrl $clone
        if ($LASTEXITCODE -ne 0) {
            throw "Cloning $script:RepoUrl failed with exit code $LASTEXITCODE, and '$Target' was not created. Check the network connection and re-run, or clone the repository yourself and run its install.ps1."
        }
        if (-not (Test-CompleteRepository $clone)) {
            throw "The clone of $script:RepoUrl does not contain .chezmoiroot, install.ps1 and packages\windows.psd1, so it was discarded. Nothing was changed."
        }

        # An empty directory at the target is what an interrupted attempt or a
        # 'mkdir' leaves behind, and it holds nothing that could be lost.
        if (Test-Path -LiteralPath $Target) {
            if (@(Get-ChildItem -LiteralPath $Target -Force).Count -gt 0) {
                throw "'$Target' appeared while cloning, so the clone was discarded instead of overwriting it. Re-run install.ps1."
            }
            Remove-Item -LiteralPath $Target -Force
        }

        Move-Item -LiteralPath $clone -Destination $Target
    }
    finally {
        if (Test-Path -LiteralPath $temporary) {
            Remove-Item -LiteralPath $temporary -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Get-DotfilesRepository {
    <#
        The repository to install from: an existing checkout at chezmoi's source
        directory or a fresh clone. Returns $null for a dry run that would have
        to clone, because the plan of the rest of the run needs the repository.
    #>

    if ([Environment]::GetEnvironmentVariable($script:BootstrapMarker)) {
        throw "The clone this installer handed over to does not look like $script:RepoSlug either, so the bootstrap stopped instead of cloning again. Clone $script:RepoUrl yourself and run its install.ps1."
    }

    $target = Get-DefaultSourceRoot
    if ((Test-Path -LiteralPath $target) -and (Test-AdoptableCheckout $target)) {
        return $target
    }

    if ($DryRun) {
        Write-Host "    would clone $script:RepoUrl (branch $script:RepoBranch) into $target"
        Write-Host "    the full plan needs the repository; clone it and run '.\install.ps1 -DryRun' inside the clone"
        return $null
    }

    Install-Git
    Invoke-GitClone -Target $target
    Add-Note "$script:RepoSlug was cloned into $target."

    return $target
}

function Get-PowerShellHostPath {
    <#
        The executable of this run, so that the installer of the clone starts in
        the same edition: the entry point is Windows PowerShell 5.1, but the
        file may also be started with pwsh.
    #>

    $process = [Diagnostics.Process]::GetCurrentProcess()
    if ($process.MainModule -and $process.MainModule.FileName) {
        return $process.MainModule.FileName
    }

    $name = 'powershell.exe'
    if ($PSVersionTable.PSEdition -eq 'Core') {
        $name = 'pwsh'
        if ($env:OS -eq 'Windows_NT') {
            $name = 'pwsh.exe'
        }
    }

    return (Join-Path $PSHOME $name)
}

function Invoke-RepoInstaller {
    <#
        The repository is the source of truth for the installer, so the rest of
        the run is done by the install.ps1 of the clone instead of by this copy,
        which may be older or may have been downloaded from anywhere.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot
    )

    $installer = Join-Path $RepoRoot 'install.ps1'
    if (-not (Test-Path -LiteralPath $installer -PathType Leaf)) {
        throw "'$installer' is missing, so the run cannot continue. Nothing was applied."
    }

    Write-Step "Running the installer of $RepoRoot"
    $arguments = @('-NoLogo', '-NoProfile')
    if ($env:OS -eq 'Windows_NT') {
        $arguments += @('-ExecutionPolicy', 'Bypass')
    }
    $arguments += @('-File', $installer)
    $arguments += $script:ForwardedArguments

    [Environment]::SetEnvironmentVariable($script:BootstrapMarker, '1')
    & (Get-PowerShellHostPath) @arguments
    exit $LASTEXITCODE
}

function Test-Administrator {
    if ($env:OS -ne 'Windows_NT') {
        return $false
    }

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal $identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

try {
    ##### Scoop root #####
    # Documents\PowerShell\Profile\env.ps1 points $env:SCOOP here, so Scoop has
    # to use the same root. Resolved before the repository, because a bootstrap
    # run installs git with Scoop.
    $script:ScoopRoot = $env:SCOOP
    if (-not $script:ScoopRoot) {
        $script:ScoopRoot = Join-Path $env:LOCALAPPDATA 'Programs\Scoop'
    }
    $script:ScoopPath = Find-Executable 'scoop'

    ##### Repository #####
    # Repository-local mode when .chezmoiroot sits next to this script, which is
    # resolved from the location of the file and not from the working directory.
    # Started on its own, the repository is fetched first and its own install.ps1
    # takes over.
    $repoRoot = $PSScriptRoot
    if (-not ($repoRoot -and (Test-RepositoryMarker $repoRoot))) {
        Write-Step 'Fetching the dotfiles repository'
        $repoRoot = Get-DotfilesRepository
        if (-not $repoRoot) {
            Write-Step 'Dry run complete, nothing was cloned'
            exit 0
        }
        Invoke-RepoInstaller -RepoRoot $repoRoot
    }

    $chezmoiRootFile = Join-Path $repoRoot '.chezmoiroot'
    $sourceDir = Join-Path $repoRoot ((Get-Content -LiteralPath $chezmoiRootFile -Raw).Trim())
    if (-not (Test-Path -LiteralPath $sourceDir -PathType Container)) {
        throw "The chezmoi source directory '$sourceDir' referenced by .chezmoiroot is missing. Check out the repository again."
    }

    $packageFile = Join-Path (Join-Path $repoRoot 'packages') 'windows.psd1'
    if (-not (Test-Path -LiteralPath $packageFile -PathType Leaf)) {
        throw "The package list '$packageFile' was not found. Check out the repository again, or use -SkipPackages to only apply the dotfiles."
    }
    $packages = Import-PowerShellDataFile -LiteralPath $packageFile

    ##### Prerequisites #####
    Write-Step 'Checking prerequisites'
    Write-Host "    host:      PowerShell $($PSVersionTable.PSVersion) on $([Environment]::OSVersion.VersionString)"
    Write-Host "    source:    $sourceDir"
    Write-Host "    scoop dir: $script:ScoopRoot"
    if ($DryRun) {
        Write-Host '    dry run: nothing is installed and the home directory is not changed'
    }
    if (Test-Administrator) {
        Add-Note 'This run is elevated. The dotfiles belong to a normal user and Scoop installs per user, so run install.ps1 without Administrator rights.'
    }

    ##### Packages #####
    if ($SkipPackages) {
        Add-Note 'Package bootstrap skipped (-SkipPackages).'
    }
    else {
        Write-Step 'Ensuring Scoop'
        if ($script:ScoopPath) {
            Write-Host "    scoop: $script:ScoopPath"
        }
        elseif ($DryRun) {
            Write-Host "    would bootstrap Scoop from https://get.scoop.sh into $script:ScoopRoot"
        }
        else {
            # Scoop is required infrastructure: Windows Terminal starts pwsh and
            # bash from the Scoop install layout, so there is no second source
            # for these packages.
            if (Install-Scoop) {
                $script:ScoopPath = Find-Executable 'scoop'
            }
            if (-not $script:ScoopPath) {
                throw "Scoop could not be bootstrapped into '$script:ScoopRoot', and it is the only package manager this repository supports. Install Scoop manually (see https://scoop.sh), then re-run install.ps1."
            }
            Write-Host "    scoop: $script:ScoopPath"
        }

        Write-Step 'Ensuring Scoop buckets'
        Add-ScoopBucket $packages.Buckets

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
    # chezmoi is one of the required packages, so the step above normally
    # installed it already. This resolves it again for the -SkipPackages case
    # and to get the path that is used for the apply below; the package entry
    # itself stays the single source of the package name.
    Write-Step 'Checking chezmoi'
    $chezmoi = Find-Executable 'chezmoi'
    if (-not $chezmoi) {
        if ($SkipChezmoiInstall) {
            throw "chezmoi was not found on PATH and -SkipChezmoiInstall was specified. Install it with 'scoop install chezmoi', then re-run install.ps1."
        }

        $chezmoiPackage = $packages.Required | Where-Object { $_.Command -eq 'chezmoi' } | Select-Object -First 1
        if (-not (Install-BootstrapPackage $chezmoiPackage)) {
            throw "chezmoi was not found and could not be installed with Scoop. Install it with 'scoop install chezmoi' (see https://www.chezmoi.io/install/), then re-run install.ps1."
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
