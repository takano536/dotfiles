param(
    [Parameter(Position = 0)]
    [string]$Command,

    [Parameter(ValueFromRemainingArguments)]
    [object[]]$Arguments
)

$sudo = "$env:WINDIR\System32\sudo.exe"

if (-not $Command) {
    & $sudo
    return
}

$commandInfo = Get-Command $Command -ErrorAction SilentlyContinue

# Native command
if ($commandInfo -and $commandInfo.CommandType -eq 'Application') {
    & $sudo $Command @Arguments
    return
}

# PowerShell command
$script = @'
$command = $args[0]
$commandArgs = @($args | Select-Object -Skip 1)
& $command @commandArgs
'@

& $sudo pwsh -NoLogo -CommandWithArgs $script $Command @Arguments