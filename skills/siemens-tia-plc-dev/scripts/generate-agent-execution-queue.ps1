param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    [string]$WorkflowConfigPath = "",
    [string]$PlanPath = "",
    [string]$TaskText = "",
    [string]$OutputDirectory = ""
)

$ErrorActionPreference = "Stop"

function Resolve-ProjectDirectory {
    param([string]$Path)
    $item = Get-Item -LiteralPath $Path
    if ($item.PSIsContainer) { return $item.FullName }
    return $item.Directory.FullName
}

function Get-ConfigValue {
    param([object]$Config, [string[]]$Path, $Fallback = "")
    $value = $Config
    foreach ($part in $Path) {
        if ($null -eq $value) { return $Fallback }
        $property = $value.PSObject.Properties[$part]
        if ($null -eq $property) { return $Fallback }
        $value = $property.Value
    }
    if ($null -eq $value) { return $Fallback }
    return [string]$value
}

function ConvertTo-JsonString {
    param([string]$Value)
    if ($null -eq $Value) { $Value = "" }
    $Value = $Value.Replace("\", "\\").Replace('"', '\"').Replace("`r", "\r").Replace("`n", "\n").Replace("`t", "\t")
    return '"' + $Value + '"'
}

function Write-Doc {
    param([string]$Path, [string]$Content)
    Set-Content -LiteralPath $Path -Value $Content -Encoding UTF8
}

function New-CommandForStage {
    param([object]$Stage, [string]$Root, [string]$InvokePath, [string]$ConfigPath, [string]$Task)
    $id = [string]$Stage.id
    if ($id -eq "context-read") {
        return "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$InvokePath`" read-cycle -ProjectPath `"$Root`" -Attach -SkipExport -WorkflowConfigPath `"$ConfigPath`""
    }
    if ($id -eq "knowledge-retrieval") {
        return "Use the selected Agent with web search enabled; write PLC_Code\knowledge\latest-knowledge-notes.md."
    }
    if ($id -eq "plc-contract") {
        return "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$InvokePath`" plc-change-package -ProjectPath `"$Root`" -TaskText `"$Task`" -Workflow data-contract -WorkflowConfigPath `"$ConfigPath`""
    }
    if ($id -eq "lad-authoring") {
        return "Edit the generated lad-json specs or donor LAD XML, then run write-lad-network/write-lad-batch and summarize-lad."
    }
    if ($id -eq "advanced-plc") {
        return "Create an instruction-route table, then use LAD JSON for readable logic, generic CALL for Siemens/library FBs, and SCL source import for algorithms."
    }
    if ($id -eq "wincc-intake" -or $id -eq "visual-reference" -or $id -eq "component-decomposition" -or $id -eq "wincc-engineering") {
        return "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$InvokePath`" wincc-visual-package -ProjectPath `"$Root`" -TaskText `"$Task`" -WorkflowConfigPath `"$ConfigPath`""
    }
    if ($id -eq "simulation-validation") {
        return "Run clone compile/readback checks; use PLCSIM or WinCC Unified runtime GraphQL only when configured and trusted."
    }
    if ($id -eq "risk-review") {
        return "Review safety-risk-assessment.md and update missing assumptions, command authority, interlocks, alarms and reset/homing risks."
    }
    if ($id -eq "release") {
        return "Prepare release only after validation; production apply-release requires explicit user confirmation."
    }
    return "Manual/Agent stage: inspect inputs, generate artifacts, verify, and record logs."
}

function New-PromptText {
    param([object]$Stage, [object]$Plan, [string]$Root)
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("# Agent Stage Prompt")
    $lines.Add("")
    $lines.Add("Project: ``$Root``")
    $lines.Add("Stage: ``$($Stage.id)`` - $($Stage.title)")
    $lines.Add("Agent: ``$($Stage.agent)``")
    $lines.Add("Workflow: ``$($Plan.workflowName)`` / ``$($Plan.workflowId)``")
    $lines.Add("")
    $lines.Add("## Task")
    $lines.Add("")
    $lines.Add([string]$Plan.taskText)
    $lines.Add("")
    $lines.Add("## Stage Duties")
    $lines.Add("")
    $lines.Add("- Tools: $($Stage.tools)")
    $lines.Add("- Outputs: $($Stage.outputs)")
    $lines.Add("- Gate: $($Stage.gate)")
    $lines.Add("- Notes: $($Stage.notes)")
    $lines.Add("")
    $lines.Add("## Non-Negotiables")
    $lines.Add("")
    $lines.Add("- Back up or clone before write-like TIA operations.")
    $lines.Add("- Keep production import/download separate from generation.")
    $lines.Add("- Use concise Chinese_English names for PLC/HMI contracts.")
    $lines.Add("- Prefer official Siemens docs and vetted community examples, then current project exports and compile logs.")
    $lines.Add("- Record generated files and verification evidence under PLC_Code.")
    return ($lines -join [Environment]::NewLine)
}

$root = Resolve-ProjectDirectory -Path $ProjectPath
$workspaceRoot = Join-Path $root "PLC_Code"
if ([string]::IsNullOrWhiteSpace($WorkflowConfigPath)) { $WorkflowConfigPath = Join-Path $workspaceRoot "config\ai-workflow.json" }
if ([string]::IsNullOrWhiteSpace($PlanPath)) { $PlanPath = Join-Path $workspaceRoot "agent-plans\latest-plan.json" }
if (-not (Test-Path -LiteralPath $PlanPath)) {
    $planScript = Join-Path $PSScriptRoot "generate-agent-task-plan.ps1"
    if (-not (Test-Path -LiteralPath $planScript)) { throw "Agent plan JSON not found and plan script is missing: $PlanPath" }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $planScript -ProjectPath $root -WorkflowConfigPath $WorkflowConfigPath -TaskText $TaskText -Workflow "agent-workbench" | Out-Null
}
if (-not (Test-Path -LiteralPath $PlanPath)) { throw "Agent plan JSON not found after generation attempt: $PlanPath" }

$config = $null
if (Test-Path -LiteralPath $WorkflowConfigPath) { $config = Get-Content -LiteralPath $WorkflowConfigPath -Raw | ConvertFrom-Json }
$plan = Get-Content -LiteralPath $PlanPath -Raw | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($TaskText)) { $TaskText = [string]$plan.taskText }

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) { $OutputDirectory = Join-Path $workspaceRoot "agent-queues\$stamp-execution-queue" }
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $OutputDirectory "prompts") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $OutputDirectory "logs") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $OutputDirectory "evidence") -Force | Out-Null

$latestDir = Join-Path $workspaceRoot "agent-queues\latest"
New-Item -ItemType Directory -Path $latestDir -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $latestDir "prompts") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $latestDir "logs") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $latestDir "evidence") -Force | Out-Null

# Keep generated queue commands inside the active skill package. This matters for
# the protected EXE, where the package is extracted to a per-session runtime root.
$invokePath = Join-Path $PSScriptRoot "invoke-siemens-plc-dev.ps1"
$routingMode = Get-ConfigValue -Config $config -Path @("platform", "routingMode") -Fallback "auto"
$platform = Get-ConfigValue -Config $config -Path @("platform", "selected") -Fallback "auto"
$model = Get-ConfigValue -Config $config -Path @("routing", "codeModel") -Fallback "inherit"
$safetyMode = Get-ConfigValue -Config $config -Path @("safety", "safetyMode") -Fallback "clone-compile"

$items = New-Object System.Collections.Generic.List[object]
$index = 1
foreach ($stage in @($plan.stages)) {
    $stageId = [string]$stage.id
    $promptName = ("{0:00}-{1}.md" -f $index, ($stageId -replace '[^A-Za-z0-9_-]', '-'))
    $promptPath = Join-Path (Join-Path $OutputDirectory "prompts") $promptName
    $latestPromptPath = Join-Path (Join-Path $latestDir "prompts") $promptName
    $promptText = New-PromptText -Stage $stage -Plan $plan -Root $root
    Write-Doc -Path $promptPath -Content $promptText
    Write-Doc -Path $latestPromptPath -Content $promptText
    $items.Add([pscustomobject]@{
        order = $index
        id = $stageId
        title = [string]$stage.title
        status = "PENDING"
        agent = [string]$stage.agent
        platform = $(if ($routingMode -eq "auto") { "auto" } else { $platform })
        model = $model
        command = (New-CommandForStage -Stage $stage -Root $root -InvokePath $invokePath -ConfigPath $WorkflowConfigPath -Task $TaskText)
        prompt = "prompts/$promptName"
        gate = [string]$stage.gate
        outputs = [string]$stage.outputs
        safetyMode = $safetyMode
    })
    $index++
}

$queue = [pscustomobject]@{
    schemaVersion = 1
    generatedAt = (Get-Date).ToString("o")
    projectRoot = $root
    planPath = (Get-Item -LiteralPath $PlanPath).FullName
    workflow = [string]$plan.workflowId
    taskText = $TaskText
    routingMode = $routingMode
    platform = $platform
    model = $model
    safetyMode = $safetyMode
    releaseAllowed = $false
    items = @($items.ToArray())
}

$queueJson = Join-Path $OutputDirectory "queue.json"
$latestJson = Join-Path $latestDir "queue.json"
$queue | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $queueJson -Encoding UTF8
$queue | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $latestJson -Encoding UTF8

$md = New-Object System.Text.StringBuilder
[void]$md.AppendLine("# Agent Execution Queue")
[void]$md.AppendLine()
[void]$md.AppendLine("- Project: ``$root``")
[void]$md.AppendLine("- Plan: ``$PlanPath``")
[void]$md.AppendLine("- Workflow: ``$($plan.workflowId)``")
[void]$md.AppendLine("- Platform: ``$platform`` / routing ``$routingMode``")
[void]$md.AppendLine("- Model: ``$model``")
[void]$md.AppendLine("- Safety mode: ``$safetyMode``")
[void]$md.AppendLine("- Release allowed: ``false``")
[void]$md.AppendLine()
[void]$md.AppendLine("## Queue")
[void]$md.AppendLine()
foreach ($item in $items) {
    [void]$md.AppendLine("### " + ("{0:00}" -f $item.order) + " " + $item.id + " - " + $item.title)
    [void]$md.AppendLine("- Status: ``" + $item.status + "``")
    [void]$md.AppendLine("- Agent: ``" + $item.agent + "``")
    [void]$md.AppendLine("- Prompt: ``" + $item.prompt + "``")
    [void]$md.AppendLine("- Command: " + $item.command)
    [void]$md.AppendLine("- Gate: " + $item.gate)
    [void]$md.AppendLine("- Outputs: " + $item.outputs)
    [void]$md.AppendLine()
}
[void]$md.AppendLine("## How To Use")
[void]$md.AppendLine()
[void]$md.AppendLine("- Execute one stage at a time from the workbench or terminal.")
[void]$md.AppendLine("- Keep every stage output under the paths listed above.")
[void]$md.AppendLine("- Mark stages complete only after artifact and gate review.")
[void]$md.AppendLine("- Do not apply production writes from this queue; create a release package after validation.")

$queueMd = Join-Path $OutputDirectory "queue.md"
$latestMd = Join-Path $latestDir "queue.md"
Write-Doc -Path $queueMd -Content $md.ToString()
Write-Doc -Path $latestMd -Content $md.ToString()

@"
{
  "status": "ok",
  "outputDirectory": "$($OutputDirectory.Replace('\', '\\'))",
  "latestDirectory": "$($latestDir.Replace('\', '\\'))",
  "queue": "$($queueJson.Replace('\', '\\'))"
}
"@
