param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    [string]$HmiName = "",

    [string]$RunName = "",

    [string]$WorkflowConfigPath = "",

    [switch]$UseUi,

    [switch]$Attach
)

$ErrorActionPreference = "Stop"

function Resolve-ProjectDirectory {
    param([string]$Path)
    $item = Get-Item -LiteralPath $Path
    if ($item.PSIsContainer) { return $item.FullName }
    return $item.Directory.FullName
}

function Invoke-Captured {
    param(
        [string]$ScriptPath,
        [string[]]$Arguments,
        [string]$LogPath
    )

    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $text = ($output | Out-String).TrimEnd()
    $text | Set-Content -LiteralPath $LogPath -Encoding UTF8
    [pscustomobject]@{
        ExitCode = $exitCode
        Output = $text
        LogPath = $LogPath
    }
}

$projectItem = Get-Item -LiteralPath $ProjectPath
$resolvedProject = $projectItem.FullName
$projectRoot = Resolve-ProjectDirectory -Path $resolvedProject
if ([string]::IsNullOrWhiteSpace($RunName)) {
    $RunName = "wincc-read-cycle-" + (Get-Date -Format "yyyyMMdd-HHmmss")
}

$workflowConfig = $null
if (-not [string]::IsNullOrWhiteSpace($WorkflowConfigPath)) {
    if (-not (Test-Path -LiteralPath $WorkflowConfigPath -PathType Leaf)) {
        throw "Workflow config not found: $WorkflowConfigPath"
    }
    $workflowConfig = Get-Content -LiteralPath $WorkflowConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
}

$runRoot = Join-Path $projectRoot "PLC_Code\wincc\readback\$RunName"
$logRoot = Join-Path $runRoot "logs"
$artifactRoot = Join-Path $runRoot "artifacts"
New-Item -ItemType Directory -Path $logRoot, $artifactRoot -Force | Out-Null

. (Join-Path $PSScriptRoot "resolve-bridge-skill.ps1")
$skillsRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$bridge = Resolve-TiaBridgeSkill -SkillsRoot $skillsRoot
$opennessScript = Resolve-TiaBridgeScript -SkillPath $bridge.SkillPath -Candidates @("scripts\invoke-tia-openness.ps1")

$args = @("read-hmi", "--project", $resolvedProject, "--output", $artifactRoot)
if (-not [string]::IsNullOrWhiteSpace($HmiName)) {
    $args += @("--hmi", $HmiName)
}
if ($UseUi) {
    $args += "--ui"
}
if ($Attach) {
    $args += "--attach"
}

Write-Host ("SESSION_MODE`tUseUi={0}`tAttach={1}`tConfig={2}" -f [bool]$UseUi, [bool]$Attach, $WorkflowConfigPath)
$result = Invoke-Captured -ScriptPath $opennessScript -Arguments $args -LogPath (Join-Path $logRoot "read-hmi.log")
$result.Output | Write-Output
if ($result.ExitCode -ne 0) {
    throw "WinCC read-cycle failed with exit code $($result.ExitCode). See $($result.LogPath)"
}

$latestRoot = Join-Path $projectRoot "PLC_Code\wincc\readback\latest"
New-Item -ItemType Directory -Path $latestRoot -Force | Out-Null
$reportSource = Join-Path $artifactRoot "wincc-readback.json"
$readmeSource = Join-Path $artifactRoot "README.md"
if (Test-Path -LiteralPath $reportSource -PathType Leaf) {
    Copy-Item -LiteralPath $reportSource -Destination (Join-Path $latestRoot "wincc-readback.json") -Force
}
if (Test-Path -LiteralPath $readmeSource -PathType Leaf) {
    Copy-Item -LiteralPath $readmeSource -Destination (Join-Path $latestRoot "README.md") -Force
}

$report = [pscustomobject]@{
    status = "ok"
    projectPath = $resolvedProject
    detectedBridge = $bridge.Version
    hmiName = $HmiName
    runRoot = $runRoot
    artifactRoot = $artifactRoot
    reportPath = $reportSource
    logPath = $result.LogPath
    usedUi = [bool]$UseUi
    attached = [bool]$Attach
    completedAt = (Get-Date).ToString("o")
    notes = @(
        "Read-only Openness operation; no PLC download was performed.",
        "If HmiTargets is zero, the project has no engineering HMI target visible to Openness.",
        "Classic WinCC exports screens, tag tables and connections when the target permits export; Unified produces object readback JSON."
    )
}
$reportPath = Join-Path $runRoot "wincc-read-cycle.json"
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $reportPath -Encoding UTF8

[pscustomobject]@{
    status = "ok"
    runRoot = $runRoot
    reportPath = $reportPath
    artifactRoot = $artifactRoot
    hmiReadback = $reportSource
} | ConvertTo-Json -Depth 6
