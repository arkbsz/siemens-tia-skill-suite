param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    [string]$WorkflowConfigPath = "",

    [string]$QueuePath = "",

    [ValidateSet("auto", "manual")]
    [string]$RoutingMode = "auto",

    [ValidateSet("auto", "codex", "claude-code", "trae-agent", "qoder")]
    [string]$Platform = "auto",

    [string]$Model = "inherit",

    [ValidateSet("read-only", "workspace-write", "danger-full-access")]
    [string]$Sandbox = "workspace-write",

    [int]$TimeoutSeconds = 900,

    [switch]$Search,

    [switch]$CompleteOnSuccess
)

$ErrorActionPreference = "Stop"
$nativeUtf8 = New-Object System.Text.UTF8Encoding($false)
$OutputEncoding = $nativeUtf8
[Console]::OutputEncoding = $nativeUtf8

function Resolve-ProjectDirectory {
    param([string]$Path)
    $item = Get-Item -LiteralPath $Path
    if ($item.PSIsContainer) { return $item.FullName }
    return $item.Directory.FullName
}

function Get-JsonPropertyValue {
    param($Object, [string]$Name, $Fallback = "")
    if ($null -eq $Object) { return $Fallback }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) { return $Fallback }
    return $property.Value
}

function Get-QueueItem {
    param([object]$Queue, [string]$Status)
    foreach ($item in @($Queue.items)) {
        if ([string]$item.status -eq $Status) { return $item }
    }
    return $null
}

function Add-Or-Set {
    param([object]$Object, [string]$Name, $Value)
    $property = $Object.PSObject.Properties[$Name]
    if ($property) { $property.Value = $Value }
    else { $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value }
}

function ConvertTo-JsonString {
    param([string]$Value)
    if ($null -eq $Value) { $Value = "" }
    $Value = $Value.Replace("\", "\\").Replace('"', '\"').Replace("`r", "\r").Replace("`n", "\n").Replace("`t", "\t")
    return '"' + $Value + '"'
}

function ConvertTo-CommandLineArgument {
    param([string]$Value)
    if ($null -eq $Value) { return '""' }
    if ($Value -notmatch '[\s"]') { return $Value }
    return '"' + ($Value -replace '"', '\"') + '"'
}

function Invoke-QueueStage {
    param([string]$Action, [string]$EvidencePath = "", [string]$Note = "")
    $scriptPath = Join-Path $PSScriptRoot "update-agent-execution-queue.ps1"
    $arguments = @("-ProjectPath", $root, "-Action", $Action, "-QueuePath", $QueuePath)
    if ($EvidencePath) { $arguments += @("-EvidencePath", $EvidencePath) }
    if ($Note) { $arguments += @("-Note", $Note) }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath @arguments | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Queue state update failed with exit code $LASTEXITCODE." }
}

$root = Resolve-ProjectDirectory -Path $ProjectPath
$workspaceRoot = Join-Path $root "PLC_Code"
if ([string]::IsNullOrWhiteSpace($WorkflowConfigPath)) { $WorkflowConfigPath = Join-Path $workspaceRoot "config\ai-workflow.json" }
if ([string]::IsNullOrWhiteSpace($QueuePath)) { $QueuePath = Join-Path $workspaceRoot "agent-queues\latest\queue.json" }
if (-not (Test-Path -LiteralPath $QueuePath -PathType Leaf)) { throw "Queue file not found: $QueuePath" }

$queue = Get-Content -LiteralPath $QueuePath -Raw -Encoding UTF8 | ConvertFrom-Json
$queueDir = Split-Path -Parent (Get-Item -LiteralPath $QueuePath).FullName
$active = Get-QueueItem -Queue $queue -Status "IN_PROGRESS"
if (-not $active) {
    Invoke-QueueStage -Action "start-next" -Note "Started automatically before Agent execution."
    $queue = Get-Content -LiteralPath $QueuePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $active = Get-QueueItem -Queue $queue -Status "IN_PROGRESS"
}
if (-not $active) { throw "No queue stage is available to run." }

$promptPath = Join-Path $queueDir ([string]$active.prompt).Replace("/", "\")
if (-not (Test-Path -LiteralPath $promptPath -PathType Leaf)) { throw "Stage prompt file not found: $promptPath" }

$agentScript = Join-Path $PSScriptRoot "invoke-ai-platform-agent.ps1"
if (-not (Test-Path -LiteralPath $agentScript -PathType Leaf)) { throw "Unified AI platform adapter not found: $agentScript" }

$stageStamp = Get-Date -Format "yyyyMMdd-HHmmss-fff"
$safeStageId = ([string]$active.id) -replace '[^A-Za-z0-9_-]', '-'
$stageEvidence = Join-Path (Join-Path $queueDir "evidence") ("$stageStamp-$safeStageId")
$stageLogs = Join-Path (Join-Path $queueDir "logs") ("$stageStamp-$safeStageId")
New-Item -ItemType Directory -Path $stageEvidence -Force | Out-Null
New-Item -ItemType Directory -Path $stageLogs -Force | Out-Null

$stdoutPath = Join-Path $stageLogs "agent.stdout.jsonl"
$stderrPath = Join-Path $stageLogs "agent.stderr.log"
$metadataPath = Join-Path $stageEvidence "stage-run.json"
$summaryPath = Join-Path $stageEvidence "stage-run.md"

$stageAgent = [string]$active.agent
if ([string]::IsNullOrWhiteSpace($stageAgent)) { $stageAgent = "auto" }
$workflow = [string]$queue.workflow
if ([string]::IsNullOrWhiteSpace($workflow)) { $workflow = "agent-queue" }
if ($Model -eq "inherit") {
    $stageModel = [string]$active.model
    if (-not [string]::IsNullOrWhiteSpace($stageModel)) { $Model = $stageModel }
}

$arguments = @(
    "-NoProfile", "-ExecutionPolicy", "Bypass",
    "-File", $agentScript,
    "-ProjectPath", $root,
    "-PromptFile", $promptPath,
    "-AgentId", $stageAgent,
    "-Workflow", $workflow,
    "-RoutingMode", $RoutingMode,
    "-Platform", $Platform,
    "-Model", $Model,
    "-Sandbox", $Sandbox
)
if ($WorkflowConfigPath -and (Test-Path -LiteralPath $WorkflowConfigPath -PathType Leaf)) {
    $arguments += @("-WorkflowConfigPath", $WorkflowConfigPath)
}
if ($Search) { $arguments += "-Search" }

$startedAt = (Get-Date).ToString("o")
$timedOut = $false
Write-Host ("Running queue stage '{0}' with timeout {1}s. Logs: {2}" -f ([string]$active.id), $TimeoutSeconds, $stageLogs)
$argumentLine = ($arguments | ForEach-Object { ConvertTo-CommandLineArgument ([string]$_) }) -join " "
$process = Start-Process -FilePath "powershell.exe" -ArgumentList $argumentLine -WorkingDirectory $root -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -PassThru -WindowStyle Hidden
try {
    if ($TimeoutSeconds -gt 0) {
        $finished = $process.WaitForExit($TimeoutSeconds * 1000)
        if (-not $finished) {
            $timedOut = $true
            try { $process.Kill() } catch { }
            $process.WaitForExit()
        }
    }
    else {
        $process.WaitForExit()
    }
}
finally {
    $exitCode = if ($timedOut) { 124 } else { $process.ExitCode }
}
$completedAt = (Get-Date).ToString("o")

$selectedPlatform = ""
$selectedModel = ""
if (Test-Path -LiteralPath $stdoutPath -PathType Leaf) {
    foreach ($line in Get-Content -LiteralPath $stdoutPath -Encoding UTF8 -ErrorAction SilentlyContinue) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try {
            $event = $line | ConvertFrom-Json -ErrorAction Stop
            if ([string](Get-JsonPropertyValue -Object $event -Name "type") -eq "platform.selected") {
                $selectedPlatform = [string](Get-JsonPropertyValue -Object $event -Name "platform")
                $selectedModel = [string](Get-JsonPropertyValue -Object $event -Name "model")
                break
            }
        }
        catch {
        }
    }
}

$metadata = [pscustomobject]@{
    status = if ($exitCode -eq 0) { "ok" } else { "failed" }
    exitCode = $exitCode
    projectRoot = $root
    queuePath = $QueuePath
    stageId = [string]$active.id
    stageTitle = [string]$active.title
    stageAgent = $stageAgent
    workflow = $workflow
    requestedRoutingMode = $RoutingMode
    requestedPlatform = $Platform
    requestedModel = $Model
    selectedPlatform = $selectedPlatform
    selectedModel = $selectedModel
    sandbox = $Sandbox
    search = [bool]$Search
    timedOut = [bool]$timedOut
    timeoutSeconds = $TimeoutSeconds
    completeOnSuccess = [bool]$CompleteOnSuccess
    promptPath = $promptPath
    stdoutPath = $stdoutPath
    stderrPath = $stderrPath
    evidencePath = $stageEvidence
    startedAt = $startedAt
    completedAt = $completedAt
}
$metadata | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $metadataPath -Encoding UTF8

$summary = @"
# Queue Stage Agent Run

- Stage: `$([string]$active.id)` - $([string]$active.title)
- Status: `$(if ($exitCode -eq 0) { "ok" } elseif ($timedOut) { "timeout" } else { "failed" })`
- Exit code: `$exitCode`
- Timed out: `$timedOut`
- Agent: `$stageAgent`
- Workflow: `$workflow`
- Requested platform: `$Platform`
- Selected platform: `$(if ($selectedPlatform) { $selectedPlatform } else { "not reported" })`
- Model: `$(if ($selectedModel) { $selectedModel } else { $Model })`
- Prompt: `$promptPath`
- Stdout: `$stdoutPath`
- Stderr: `$stderrPath`
- Started: `$startedAt`
- Completed: `$completedAt`

Review the stdout JSONL and generated project artifacts before marking a write-like stage as complete.
"@
$summary | Set-Content -LiteralPath $summaryPath -Encoding UTF8

if ($exitCode -eq 0) {
    $note = if ($CompleteOnSuccess) { "Agent execution succeeded; stage marked complete by queue-run-current." } else { "Agent execution succeeded; evidence recorded, manual completion is still required." }
    if ($CompleteOnSuccess) {
        Invoke-QueueStage -Action "complete-current" -EvidencePath $stageEvidence -Note $note
    }
    else {
        Invoke-QueueStage -Action "record-current" -EvidencePath $stageEvidence -Note $note
    }
}
else {
    $failNote = if ($timedOut) { "Agent execution timed out after $TimeoutSeconds seconds; inspect stdout/stderr before retry." } else { "Agent execution failed; inspect stdout/stderr before retry." }
    Invoke-QueueStage -Action "fail-current" -EvidencePath $stageEvidence -Note $failNote
}

@"
{
  "status": "$(if ($exitCode -eq 0) { "ok" } else { "failed" })",
  "exitCode": $exitCode,
  "stageId": $(ConvertTo-JsonString ([string]$active.id)),
  "evidencePath": $(ConvertTo-JsonString $stageEvidence),
  "stdoutPath": $(ConvertTo-JsonString $stdoutPath),
  "stderrPath": $(ConvertTo-JsonString $stderrPath)
}
"@

exit $exitCode
