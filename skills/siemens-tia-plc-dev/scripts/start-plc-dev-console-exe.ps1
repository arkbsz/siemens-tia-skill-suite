param(
    [string]$ProjectPath = "",

    [switch]$Wait,

    [switch]$ForceBuild
)

$ErrorActionPreference = "Stop"

$skillRoot = Split-Path -Parent $PSScriptRoot
$buildScript = Join-Path $PSScriptRoot "build-plc-dev-console-exe.ps1"
$invokeScript = Join-Path $PSScriptRoot "invoke-siemens-plc-dev.ps1"

if (-not (Test-Path -LiteralPath $buildScript)) {
    throw "Missing build script: $buildScript"
}

$buildArgs = @()
if ($ForceBuild) {
    $buildArgs += "-Force"
}

$buildOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $buildScript @buildArgs
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

$buildInfo = ($buildOutput | Out-String).Trim() | ConvertFrom-Json
$exePath = $buildInfo.ExePath
if (-not (Test-Path -LiteralPath $exePath)) {
    throw "Built exe was not found: $exePath"
}

$argumentList = @("--invoke", $invokeScript)
if ($ProjectPath) {
    $argumentList += @("--project", $ProjectPath)
}

if ($Wait) {
    & $exePath @argumentList
    exit $LASTEXITCODE
}

$process = Start-Process -FilePath $exePath -ArgumentList $argumentList -PassThru -WindowStyle Normal
[pscustomobject]@{
    ExePath = $exePath
    ProcessId = $process.Id
    ProjectPath = $ProjectPath
    BuildStatus = $buildInfo.Status
} | ConvertTo-Json -Depth 4
