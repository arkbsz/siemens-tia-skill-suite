param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    [ValidateSet("start-next", "record-current", "complete-current", "fail-current", "block-current", "reset")]
    [string]$Action = "start-next",

    [string]$QueuePath = "",
    [string]$Note = "",
    [string]$EvidencePath = ""
)

$ErrorActionPreference = "Stop"

function Resolve-ProjectDirectory {
    param([string]$Path)
    $item = Get-Item -LiteralPath $Path
    if ($item.PSIsContainer) { return $item.FullName }
    return $item.Directory.FullName
}

function Write-Doc {
    param([string]$Path, [string]$Content)
    Set-Content -LiteralPath $Path -Value $Content -Encoding UTF8
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
    if ($property) {
        $property.Value = $Value
    }
    else {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    }
}

function ConvertTo-JsonString {
    param([string]$Value)
    if ($null -eq $Value) { $Value = "" }
    $Value = $Value.Replace("\", "\\").Replace('"', '\"').Replace("`r", "\r").Replace("`n", "\n").Replace("`t", "\t")
    return '"' + $Value + '"'
}

function Write-QueueMarkdown {
    param([object]$Queue, [string]$Path)
    $md = New-Object System.Text.StringBuilder
    [void]$md.AppendLine("# Agent Execution Queue")
    [void]$md.AppendLine()
    [void]$md.AppendLine("- Project: ``$($Queue.projectRoot)``")
    [void]$md.AppendLine("- Workflow: ``$($Queue.workflow)``")
    [void]$md.AppendLine("- Platform: ``$($Queue.platform)`` / routing ``$($Queue.routingMode)``")
    [void]$md.AppendLine("- Model: ``$($Queue.model)``")
    [void]$md.AppendLine("- Safety mode: ``$($Queue.safetyMode)``")
    [void]$md.AppendLine("- Release allowed: ``$($Queue.releaseAllowed)``")
    [void]$md.AppendLine("- Updated: ``$(Get-Date -Format o)``")
    [void]$md.AppendLine()
    [void]$md.AppendLine("## Queue")
    [void]$md.AppendLine()
    foreach ($item in @($Queue.items)) {
        [void]$md.AppendLine("### " + ("{0:00}" -f [int]$item.order) + " " + $item.id + " - " + $item.title)
        [void]$md.AppendLine("- Status: ``" + $item.status + "``")
        [void]$md.AppendLine("- Agent: ``" + $item.agent + "``")
        [void]$md.AppendLine("- Prompt: ``" + $item.prompt + "``")
        [void]$md.AppendLine("- Command: " + $item.command)
        [void]$md.AppendLine("- Gate: " + $item.gate)
        [void]$md.AppendLine("- Outputs: " + $item.outputs)
        if ($item.startedAt) { [void]$md.AppendLine("- Started: ``" + $item.startedAt + "``") }
        if ($item.completedAt) { [void]$md.AppendLine("- Completed: ``" + $item.completedAt + "``") }
        if ($item.note) { [void]$md.AppendLine("- Note: " + $item.note) }
        if ($item.evidence) { [void]$md.AppendLine("- Evidence: ``" + $item.evidence + "``") }
        [void]$md.AppendLine()
    }
    [void]$md.AppendLine("## Operating Rule")
    [void]$md.AppendLine()
    [void]$md.AppendLine("Only one stage should be `IN_PROGRESS`. Write-like TIA operations stay behind backup, clone compile, readback comparison and explicit release gates.")
    Write-Doc -Path $Path -Content $md.ToString()
}

$root = Resolve-ProjectDirectory -Path $ProjectPath
$workspaceRoot = Join-Path $root "PLC_Code"
if ([string]::IsNullOrWhiteSpace($QueuePath)) { $QueuePath = Join-Path $workspaceRoot "agent-queues\latest\queue.json" }
if (-not (Test-Path -LiteralPath $QueuePath)) { throw "Queue file not found: $QueuePath" }

$queue = Get-Content -LiteralPath $QueuePath -Raw | ConvertFrom-Json
$queueDir = Split-Path -Parent (Get-Item -LiteralPath $QueuePath).FullName
$now = (Get-Date).ToString("o")
$selected = $null

if ($Action -eq "reset") {
    foreach ($item in @($queue.items)) {
        Add-Or-Set -Object $item -Name "status" -Value "PENDING"
        Add-Or-Set -Object $item -Name "startedAt" -Value ""
        Add-Or-Set -Object $item -Name "completedAt" -Value ""
        Add-Or-Set -Object $item -Name "note" -Value ""
        Add-Or-Set -Object $item -Name "evidence" -Value ""
    }
}
elseif ($Action -eq "start-next") {
    $current = Get-QueueItem -Queue $queue -Status "IN_PROGRESS"
    if ($current) { $selected = $current }
    else {
        foreach ($item in @($queue.items)) {
            if ([string]$item.status -eq "PENDING") {
                $selected = $item
                break
            }
        }
        if (-not $selected) { throw "No pending queue stage was found." }
        Add-Or-Set -Object $selected -Name "status" -Value "IN_PROGRESS"
        Add-Or-Set -Object $selected -Name "startedAt" -Value $now
    }
}
else {
    $selected = Get-QueueItem -Queue $queue -Status "IN_PROGRESS"
    if (-not $selected) { throw "No current IN_PROGRESS stage was found. Run start-next first." }
    if ($Action -eq "record-current") {
        Add-Or-Set -Object $selected -Name "lastRecordedAt" -Value $now
    }
    elseif ($Action -eq "complete-current") {
        Add-Or-Set -Object $selected -Name "status" -Value "DONE"
        Add-Or-Set -Object $selected -Name "completedAt" -Value $now
    }
    elseif ($Action -eq "fail-current") {
        Add-Or-Set -Object $selected -Name "status" -Value "FAILED"
        Add-Or-Set -Object $selected -Name "completedAt" -Value $now
    }
    elseif ($Action -eq "block-current") {
        Add-Or-Set -Object $selected -Name "status" -Value "BLOCKED"
        Add-Or-Set -Object $selected -Name "completedAt" -Value $now
    }
}

if ($selected) {
    if (-not [string]::IsNullOrWhiteSpace($Note)) { Add-Or-Set -Object $selected -Name "note" -Value $Note }
    if (-not [string]::IsNullOrWhiteSpace($EvidencePath)) { Add-Or-Set -Object $selected -Name "evidence" -Value $EvidencePath }
}

Add-Or-Set -Object $queue -Name "updatedAt" -Value $now
$queue | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $QueuePath -Encoding UTF8

$queueMd = Join-Path $queueDir "queue.md"
Write-QueueMarkdown -Queue $queue -Path $queueMd

$currentStageMd = Join-Path $queueDir "current-stage.md"
$currentStageJson = Join-Path $queueDir "current-stage.json"
$active = Get-QueueItem -Queue $queue -Status "IN_PROGRESS"
if ($active) {
    $promptPath = Join-Path $queueDir ([string]$active.prompt).Replace('/', '\')
    $promptText = if (Test-Path -LiteralPath $promptPath) { Get-Content -LiteralPath $promptPath -Raw } else { "" }
    $current = [pscustomobject]@{
        status = "ok"
        action = $Action
        stageId = [string]$active.id
        stageTitle = [string]$active.title
        stageStatus = [string]$active.status
        agent = [string]$active.agent
        command = [string]$active.command
        gate = [string]$active.gate
        outputs = [string]$active.outputs
        promptPath = $promptPath
        queuePath = $QueuePath
        queueMarkdown = $queueMd
    }
    Write-Doc -Path $currentStageMd -Content (($promptText.TrimEnd()) + [Environment]::NewLine + [Environment]::NewLine + "## Suggested Command" + [Environment]::NewLine + [Environment]::NewLine + [string]$active.command)
    $current | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $currentStageJson -Encoding UTF8
}
else {
    Write-Doc -Path $currentStageMd -Content "No active queue stage."
    [pscustomobject]@{ status = "ok"; action = $Action; stage = $null; queuePath = $QueuePath; queueMarkdown = $queueMd } |
        ConvertTo-Json -Depth 8 |
        Set-Content -LiteralPath $currentStageJson -Encoding UTF8
}

$result = New-Object System.Text.StringBuilder
[void]$result.AppendLine("{")
[void]$result.AppendLine('  "status": "ok",')
[void]$result.AppendLine('  "action": ' + (ConvertTo-JsonString $Action) + ',')
[void]$result.AppendLine('  "queuePath": ' + (ConvertTo-JsonString $QueuePath) + ',')
[void]$result.AppendLine('  "queueMarkdown": ' + (ConvertTo-JsonString $queueMd) + ',')
[void]$result.AppendLine('  "currentStage": ' + (ConvertTo-JsonString $currentStageMd))
[void]$result.AppendLine("}")
$result.ToString()
