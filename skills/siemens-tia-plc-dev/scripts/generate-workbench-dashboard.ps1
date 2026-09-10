param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    [string]$WorkflowConfigPath = "",

    [string]$OutputDirectory = ""
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

function Read-ShortText {
    param([string]$Path, [int]$Max = 6000)
    if ([string]::IsNullOrWhiteSpace($Path)) { return "" }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return "" }
    $text = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($null -eq $text) { return "" }
    if ($text.Length -gt $Max) { return $text.Substring(0, $Max) + "`r`n... truncated ..." }
    return $text
}

function Invoke-GitText {
    param([string]$Root, [string[]]$Arguments)
    if ([string]::IsNullOrWhiteSpace($Root)) { return "" }
    try {
        $output = & git -C $Root @Arguments 2>&1 | ForEach-Object { [string]$_ }
        return ($output -join [Environment]::NewLine)
    }
    catch {
        return ""
    }
}

function Get-QueueSummary {
    param([string]$QueuePath)
    if ([string]::IsNullOrWhiteSpace($QueuePath)) {
        return [pscustomobject]@{ exists = $false; total = 0; pending = 0; inProgress = 0; done = 0; failed = 0; blocked = 0; currentStage = "" }
    }
    if (-not (Test-Path -LiteralPath $QueuePath -PathType Leaf)) {
        return [pscustomobject]@{ exists = $false; total = 0; pending = 0; inProgress = 0; done = 0; failed = 0; blocked = 0; currentStage = "" }
    }
    $queue = Get-Content -LiteralPath $QueuePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $items = @($queue.items)
    $current = $items | Where-Object { [string]$_.status -eq "IN_PROGRESS" } | Select-Object -First 1
    return [pscustomobject]@{
        exists = $true
        total = $items.Count
        pending = @($items | Where-Object { [string]$_.status -eq "PENDING" }).Count
        inProgress = @($items | Where-Object { [string]$_.status -eq "IN_PROGRESS" }).Count
        done = @($items | Where-Object { [string]$_.status -eq "DONE" }).Count
        failed = @($items | Where-Object { [string]$_.status -eq "FAILED" }).Count
        blocked = @($items | Where-Object { [string]$_.status -eq "BLOCKED" }).Count
        currentStage = if ($current) { ([string]$current.id + " - " + [string]$current.title) } else { "" }
    }
}

function Get-LatestRun {
    param([string]$RunsRoot, [string]$Prefix = "")
    if (-not (Test-Path -LiteralPath $RunsRoot -PathType Container)) { return $null }
    $dirs = Get-ChildItem -LiteralPath $RunsRoot -Directory -ErrorAction SilentlyContinue
    if ($Prefix) { $dirs = $dirs | Where-Object { $_.Name -like "$Prefix*" } }
    return $dirs | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

$root = Resolve-ProjectDirectory -Path $ProjectPath
$workspaceRoot = Join-Path $root "PLC_Code"
if ([string]::IsNullOrWhiteSpace($WorkflowConfigPath)) { $WorkflowConfigPath = Join-Path $workspaceRoot "config\ai-workflow.json" }
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) { $OutputDirectory = Join-Path $workspaceRoot "workbench\latest" }
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

$planMd = Join-Path $workspaceRoot "agent-plans\latest-plan.md"
$queueJson = Join-Path $workspaceRoot "agent-queues\latest\queue.json"
$queueMd = Join-Path $workspaceRoot "agent-queues\latest\queue.md"
$pluginRouting = Join-Path $workspaceRoot "wincc\plugin-routing.json"
$instructionRoute = Join-Path $workspaceRoot "plc\instruction-plans\latest\instruction-route-table.md"
$instructionCookbook = Join-Path $workspaceRoot "plc\instruction-cookbook\latest\instruction-cookbook.md"
$safetyRisk = Join-Path $workspaceRoot "plc\instruction-plans\latest\safety-risk-assessment.md"
$winccComponentBlueprints = Join-Path $workspaceRoot "wincc\component-blueprints\latest\component-blueprints.md"
$winccEngineeringScaffold = Join-Path $workspaceRoot "wincc\engineering-scaffold\latest\wincc-engineering-scaffold.md"
$winccOpennessImplementation = Join-Path $workspaceRoot "wincc\openness-implementation\latest\README.md"
$winccReadback = Join-Path $workspaceRoot "wincc\readback\latest\wincc-readback.json"
$winccImplementationRunsRoot = Join-Path $workspaceRoot "wincc\openness-implementation"
$simulationPackage = Join-Path $workspaceRoot "simulation\latest\simulation-package.md"
$simulationReplay = Join-Path $workspaceRoot "simulation\replays\latest\replay-report.md"
$pipelineSummary = Join-Path $workspaceRoot "workbench\pipelines\latest\pipeline-summary.md"
$pipelineSummaryJson = Join-Path $workspaceRoot "workbench\pipelines\latest\pipeline-summary.json"
$projectModel = Join-Path $workspaceRoot "workbench\context\latest\project-model.json"
$agentContext = Join-Path $workspaceRoot "workbench\context\latest\agent-context.md"
$knowledgeBrief = Join-Path $workspaceRoot "knowledge\packs\latest\knowledge-brief.md"
$knowledgePack = Join-Path $workspaceRoot "knowledge\packs\latest\knowledge-pack.json"
$capabilityMap = Join-Path $workspaceRoot "workbench\capabilities\latest\capability-map.md"
$capabilityJson = Join-Path $workspaceRoot "workbench\capabilities\latest\capability-map.json"
$readinessPath = Join-Path $workspaceRoot "review-packages\latest\import-readiness.json"
$approvalPath = Join-Path $workspaceRoot "review-packages\latest\approval.json"
$reviewSummary = Join-Path $workspaceRoot "review-packages\latest\review-summary.md"
$runsRoot = Join-Path $workspaceRoot "runs"
$latestRun = Get-LatestRun -RunsRoot $runsRoot
$latestWriteRun = Get-LatestRun -RunsRoot $runsRoot -Prefix "write-cycle"
$latestWinccImplementationRun = Get-LatestRun -RunsRoot $winccImplementationRunsRoot -Prefix "wincc-implementation-"

$queueSummary = Get-QueueSummary -QueuePath $queueJson
$gitStatus = Invoke-GitText -Root $root -Arguments @("status", "--short")
$gitDiffStat = Invoke-GitText -Root $root -Arguments @("diff", "--stat")
$gitDiff = Invoke-GitText -Root $root -Arguments @("diff", "--", "PLC_Code")
if ([string]::IsNullOrWhiteSpace($gitDiff)) {
    $gitDiff = Invoke-GitText -Root $root -Arguments @("diff")
}

$diffPath = Join-Path $OutputDirectory "diff-summary.patch"
if ([string]::IsNullOrWhiteSpace($gitDiff)) {
    "No git diff is available for this project root." | Set-Content -LiteralPath $diffPath -Encoding UTF8
}
else {
    $gitDiff | Set-Content -LiteralPath $diffPath -Encoding UTF8
}

$latestRunReport = if ($latestRun) { Join-Path $latestRun.FullName "workflow-report.json" } else { "" }
$latestWriteReport = if ($latestWriteRun) { Join-Path $latestWriteRun.FullName "workflow-report.json" } else { "" }
$readinessText = Read-ShortText -Path $readinessPath -Max 3000
$pluginText = Read-ShortText -Path $pluginRouting -Max 5000
$latestRunText = Read-ShortText -Path $latestRunReport -Max 5000
$latestWriteText = Read-ShortText -Path $latestWriteReport -Max 5000
$instructionRouteText = Read-ShortText -Path $instructionRoute -Max 5000
$instructionCookbookText = Read-ShortText -Path $instructionCookbook -Max 5000
$safetyRiskText = Read-ShortText -Path $safetyRisk -Max 5000
$winccComponentBlueprintText = Read-ShortText -Path $winccComponentBlueprints -Max 5000
$winccEngineeringScaffoldText = Read-ShortText -Path $winccEngineeringScaffold -Max 5000
$winccOpennessImplementationText = Read-ShortText -Path $winccOpennessImplementation -Max 5000
$winccReadbackText = Read-ShortText -Path $winccReadback -Max 5000
$winccImplementationRunPath = if ($latestWinccImplementationRun) { Join-Path $latestWinccImplementationRun.FullName "implementation-run.json" } else { "" }
$winccImplementationRunText = Read-ShortText -Path $winccImplementationRunPath -Max 5000
$simulationPackageText = Read-ShortText -Path $simulationPackage -Max 5000
$simulationReplayText = Read-ShortText -Path $simulationReplay -Max 5000
$pipelineText = Read-ShortText -Path $pipelineSummary -Max 5000
$agentContextText = Read-ShortText -Path $agentContext -Max 5000
$knowledgeText = Read-ShortText -Path $knowledgeBrief -Max 5000
$capabilityText = Read-ShortText -Path $capabilityMap -Max 5000
$approvalText = Read-ShortText -Path $approvalPath -Max 5000
$approvalObject = $null
if (Test-Path -LiteralPath $approvalPath -PathType Leaf) {
    try { $approvalObject = Get-Content -LiteralPath $approvalPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $approvalObject = $null }
}
$approvalStatus = if ($approvalObject) { [string]$approvalObject.status } else { "MISSING" }
$approvedFor = if ($approvalObject) { [string]$approvalObject.approvedFor } else { "none" }

$validationMd = Join-Path $OutputDirectory "validation-summary.md"
$latestRunDisplay = if ($latestRun) { $latestRun.FullName } else { "none" }
$latestWriteDisplay = if ($latestWriteRun) { $latestWriteRun.FullName } else { "none" }
$validationBuilder = New-Object System.Text.StringBuilder
[void]$validationBuilder.AppendLine("# Validation Panel")
[void]$validationBuilder.AppendLine()
[void]$validationBuilder.AppendLine("- Project: ``$root``")
[void]$validationBuilder.AppendLine("- Workflow config: ``$WorkflowConfigPath``")
[void]$validationBuilder.AppendLine("- Latest run: ``$latestRunDisplay``")
[void]$validationBuilder.AppendLine("- Latest write-cycle run: ``$latestWriteDisplay``")
[void]$validationBuilder.AppendLine("- Import readiness: ``$readinessPath``")
[void]$validationBuilder.AppendLine("- Queue: ``$queueJson``")
[void]$validationBuilder.AppendLine("- Project model: ``$projectModel``")
[void]$validationBuilder.AppendLine("- Agent context: ``$agentContext``")
[void]$validationBuilder.AppendLine("- Knowledge brief: ``$knowledgeBrief``")
[void]$validationBuilder.AppendLine("- Capability map: ``$capabilityMap``")
[void]$validationBuilder.AppendLine("- PLC instruction cookbook: ``$instructionCookbook``")
[void]$validationBuilder.AppendLine("- WinCC component blueprints: ``$winccComponentBlueprints``")
[void]$validationBuilder.AppendLine("- WinCC engineering scaffold: ``$winccEngineeringScaffold``")
[void]$validationBuilder.AppendLine("- WinCC Openness implementation package: ``$winccOpennessImplementation``")
[void]$validationBuilder.AppendLine("- Simulation package: ``$simulationPackage``")
[void]$validationBuilder.AppendLine("- Simulation replay: ``$simulationReplay``")
[void]$validationBuilder.AppendLine("- Generated: ``$(Get-Date -Format o)``")
[void]$validationBuilder.AppendLine()
[void]$validationBuilder.AppendLine("## Queue Health")
[void]$validationBuilder.AppendLine()
[void]$validationBuilder.AppendLine("- Exists: ``$($queueSummary.exists)``")
[void]$validationBuilder.AppendLine("- Total: ``$($queueSummary.total)``")
[void]$validationBuilder.AppendLine("- Pending: ``$($queueSummary.pending)``")
[void]$validationBuilder.AppendLine("- In progress: ``$($queueSummary.inProgress)``")
[void]$validationBuilder.AppendLine("- Done: ``$($queueSummary.done)``")
[void]$validationBuilder.AppendLine("- Failed: ``$($queueSummary.failed)``")
[void]$validationBuilder.AppendLine("- Blocked: ``$($queueSummary.blocked)``")
[void]$validationBuilder.AppendLine("- Current stage: ``$($queueSummary.currentStage)``")
[void]$validationBuilder.AppendLine()
[void]$validationBuilder.AppendLine("## Agent Development Pipeline")
[void]$validationBuilder.AppendLine()
[void]$validationBuilder.AppendLine('```text')
[void]$validationBuilder.AppendLine($pipelineText)
[void]$validationBuilder.AppendLine('```')
[void]$validationBuilder.AppendLine()
[void]$validationBuilder.AppendLine("## Project Object Model")
[void]$validationBuilder.AppendLine()
[void]$validationBuilder.AppendLine('```text')
[void]$validationBuilder.AppendLine($agentContextText)
[void]$validationBuilder.AppendLine('```')
[void]$validationBuilder.AppendLine()
[void]$validationBuilder.AppendLine("## Knowledge Pack")
[void]$validationBuilder.AppendLine()
[void]$validationBuilder.AppendLine('```text')
[void]$validationBuilder.AppendLine($knowledgeText)
[void]$validationBuilder.AppendLine('```')
[void]$validationBuilder.AppendLine()
[void]$validationBuilder.AppendLine("## Editor-Replacement Capability Map")
[void]$validationBuilder.AppendLine()
[void]$validationBuilder.AppendLine('```text')
[void]$validationBuilder.AppendLine($capabilityText)
[void]$validationBuilder.AppendLine('```')
[void]$validationBuilder.AppendLine()
[void]$validationBuilder.AppendLine("## Import Readiness")
[void]$validationBuilder.AppendLine()
[void]$validationBuilder.AppendLine('```json')
[void]$validationBuilder.AppendLine($readinessText)
[void]$validationBuilder.AppendLine('```')
[void]$validationBuilder.AppendLine()
[void]$validationBuilder.AppendLine("## Release Approval")
[void]$validationBuilder.AppendLine()
[void]$validationBuilder.AppendLine("- Approval file: ``$approvalPath``")
[void]$validationBuilder.AppendLine("- Status: ``$approvalStatus``")
[void]$validationBuilder.AppendLine("- Approved for: ``$approvedFor``")
[void]$validationBuilder.AppendLine('```json')
[void]$validationBuilder.AppendLine($approvalText)
[void]$validationBuilder.AppendLine('```')
[void]$validationBuilder.AppendLine()
[void]$validationBuilder.AppendLine("## Latest Run Report")
[void]$validationBuilder.AppendLine()
[void]$validationBuilder.AppendLine('```json')
[void]$validationBuilder.AppendLine($latestRunText)
[void]$validationBuilder.AppendLine('```')
[void]$validationBuilder.AppendLine()
[void]$validationBuilder.AppendLine("## Latest Write-Cycle Report")
[void]$validationBuilder.AppendLine()
[void]$validationBuilder.AppendLine('```json')
[void]$validationBuilder.AppendLine($latestWriteText)
[void]$validationBuilder.AppendLine('```')
[void]$validationBuilder.AppendLine()
[void]$validationBuilder.AppendLine("## PLC Instruction Route")
[void]$validationBuilder.AppendLine()
[void]$validationBuilder.AppendLine('```text')
[void]$validationBuilder.AppendLine($instructionRouteText)
[void]$validationBuilder.AppendLine('```')
[void]$validationBuilder.AppendLine()
[void]$validationBuilder.AppendLine("## PLC Instruction Cookbook")
[void]$validationBuilder.AppendLine()
[void]$validationBuilder.AppendLine('```text')
[void]$validationBuilder.AppendLine($instructionCookbookText)
[void]$validationBuilder.AppendLine('```')
[void]$validationBuilder.AppendLine()
[void]$validationBuilder.AppendLine("## WinCC Component Blueprints")
[void]$validationBuilder.AppendLine()
[void]$validationBuilder.AppendLine('```text')
[void]$validationBuilder.AppendLine($winccComponentBlueprintText)
[void]$validationBuilder.AppendLine('```')
[void]$validationBuilder.AppendLine()
[void]$validationBuilder.AppendLine("## WinCC Engineering Scaffold")
[void]$validationBuilder.AppendLine()
[void]$validationBuilder.AppendLine('```text')
[void]$validationBuilder.AppendLine($winccEngineeringScaffoldText)
[void]$validationBuilder.AppendLine('```')
[void]$validationBuilder.AppendLine()
[void]$validationBuilder.AppendLine("## WinCC Openness Implementation Package")
[void]$validationBuilder.AppendLine()
[void]$validationBuilder.AppendLine('```text')
[void]$validationBuilder.AppendLine($winccOpennessImplementationText)
[void]$validationBuilder.AppendLine('```')
[void]$validationBuilder.AppendLine()
[void]$validationBuilder.AppendLine("## WinCC Real Readback")
[void]$validationBuilder.AppendLine()
[void]$validationBuilder.AppendLine('```json')
[void]$validationBuilder.AppendLine($winccReadbackText)
[void]$validationBuilder.AppendLine('```')
[void]$validationBuilder.AppendLine()
[void]$validationBuilder.AppendLine("## WinCC Clone Implementation Run")
[void]$validationBuilder.AppendLine()
[void]$validationBuilder.AppendLine('```json')
[void]$validationBuilder.AppendLine($winccImplementationRunText)
[void]$validationBuilder.AppendLine('```')
[void]$validationBuilder.AppendLine()
[void]$validationBuilder.AppendLine("## Simulation Package")
[void]$validationBuilder.AppendLine()
[void]$validationBuilder.AppendLine('```text')
[void]$validationBuilder.AppendLine($simulationPackageText)
[void]$validationBuilder.AppendLine('```')
[void]$validationBuilder.AppendLine()
[void]$validationBuilder.AppendLine("## Simulation Replay")
[void]$validationBuilder.AppendLine()
[void]$validationBuilder.AppendLine('```text')
[void]$validationBuilder.AppendLine($simulationReplayText)
[void]$validationBuilder.AppendLine('```')
[void]$validationBuilder.AppendLine()
[void]$validationBuilder.AppendLine("## Safety Risk Assessment")
[void]$validationBuilder.AppendLine()
[void]$validationBuilder.AppendLine('```text')
[void]$validationBuilder.AppendLine($safetyRiskText)
[void]$validationBuilder.AppendLine('```')
$validationBuilder.ToString() | Set-Content -LiteralPath $validationMd -Encoding UTF8

$dashboardMd = Join-Path $OutputDirectory "dashboard.md"
$planDisplay = if (Test-Path -LiteralPath $planMd) { $planMd } else { "missing" }
$queueDisplay = if (Test-Path -LiteralPath $queueMd) { $queueMd } else { "missing" }
$instructionDisplay = if (Test-Path -LiteralPath $instructionRoute -PathType Leaf) { $instructionRoute } else { "missing" }
$cookbookDisplay = if (Test-Path -LiteralPath $instructionCookbook -PathType Leaf) { $instructionCookbook } else { "missing" }
$safetyDisplay = if (Test-Path -LiteralPath $safetyRisk -PathType Leaf) { $safetyRisk } else { "missing" }
$blueprintDisplay = if (Test-Path -LiteralPath $winccComponentBlueprints -PathType Leaf) { $winccComponentBlueprints } else { "missing" }
$engineeringDisplay = if (Test-Path -LiteralPath $winccEngineeringScaffold -PathType Leaf) { $winccEngineeringScaffold } else { "missing" }
$winccImplementationDisplay = if (Test-Path -LiteralPath $winccOpennessImplementation -PathType Leaf) { $winccOpennessImplementation } else { "missing" }
$winccReadbackDisplay = if (Test-Path -LiteralPath $winccReadback -PathType Leaf) { $winccReadback } else { "missing" }
$winccImplementationRunDisplay = if ($winccImplementationRunPath -and (Test-Path -LiteralPath $winccImplementationRunPath -PathType Leaf)) { $winccImplementationRunPath } else { "missing" }
$simulationDisplay = if (Test-Path -LiteralPath $simulationPackage -PathType Leaf) { $simulationPackage } else { "missing" }
$simulationReplayDisplay = if (Test-Path -LiteralPath $simulationReplay -PathType Leaf) { $simulationReplay } else { "missing" }
$pipelineDisplay = if (Test-Path -LiteralPath $pipelineSummary -PathType Leaf) { $pipelineSummary } else { "missing" }
$projectModelDisplay = if (Test-Path -LiteralPath $projectModel -PathType Leaf) { $projectModel } else { "missing" }
$agentContextDisplay = if (Test-Path -LiteralPath $agentContext -PathType Leaf) { $agentContext } else { "missing" }
$knowledgeDisplay = if (Test-Path -LiteralPath $knowledgeBrief -PathType Leaf) { $knowledgeBrief } else { "missing" }
$capabilityDisplay = if (Test-Path -LiteralPath $capabilityMap -PathType Leaf) { $capabilityMap } else { "missing" }
$reviewDisplay = if (Test-Path -LiteralPath $reviewSummary) { $reviewSummary } else { "missing" }
$approvalDisplay = if (Test-Path -LiteralPath $approvalPath) { $approvalPath } else { "missing" }
$pluginDisplay = if (Test-Path -LiteralPath $pluginRouting) { $pluginRouting } else { "missing" }
$dashboardBuilder = New-Object System.Text.StringBuilder
[void]$dashboardBuilder.AppendLine("# Siemens TIA Workbench Dashboard")
[void]$dashboardBuilder.AppendLine()
[void]$dashboardBuilder.AppendLine("Generated: ``$(Get-Date -Format o)``")
[void]$dashboardBuilder.AppendLine("Project: ``$root``")
[void]$dashboardBuilder.AppendLine()
[void]$dashboardBuilder.AppendLine("## Current State")
[void]$dashboardBuilder.AppendLine()
[void]$dashboardBuilder.AppendLine("- Plan: ``$planDisplay``")
[void]$dashboardBuilder.AppendLine("- Queue: ``$queueDisplay``")
[void]$dashboardBuilder.AppendLine("- Validation panel: ``$validationMd``")
[void]$dashboardBuilder.AppendLine("- Diff panel: ``$diffPath``")
[void]$dashboardBuilder.AppendLine("- PLC instruction route: ``$instructionDisplay``")
[void]$dashboardBuilder.AppendLine("- PLC instruction cookbook: ``$cookbookDisplay``")
[void]$dashboardBuilder.AppendLine("- Safety risk: ``$safetyDisplay``")
[void]$dashboardBuilder.AppendLine("- WinCC component blueprints: ``$blueprintDisplay``")
[void]$dashboardBuilder.AppendLine("- WinCC engineering scaffold: ``$engineeringDisplay``")
[void]$dashboardBuilder.AppendLine("- WinCC Openness implementation package: ``$winccImplementationDisplay``")
[void]$dashboardBuilder.AppendLine("- WinCC real readback: ``$winccReadbackDisplay``")
[void]$dashboardBuilder.AppendLine("- WinCC clone implementation run: ``$winccImplementationRunDisplay``")
[void]$dashboardBuilder.AppendLine("- Simulation package: ``$simulationDisplay``")
[void]$dashboardBuilder.AppendLine("- Simulation replay: ``$simulationReplayDisplay``")
[void]$dashboardBuilder.AppendLine("- Agent pipeline: ``$pipelineDisplay``")
[void]$dashboardBuilder.AppendLine("- Project model: ``$projectModelDisplay``")
[void]$dashboardBuilder.AppendLine("- Agent context: ``$agentContextDisplay``")
[void]$dashboardBuilder.AppendLine("- Knowledge pack: ``$knowledgeDisplay``")
[void]$dashboardBuilder.AppendLine("- Capability map: ``$capabilityDisplay``")
[void]$dashboardBuilder.AppendLine("- Review package: ``$reviewDisplay``")
[void]$dashboardBuilder.AppendLine("- Release approval: ``$approvalDisplay``")
[void]$dashboardBuilder.AppendLine("- WinCC plugin routing: ``$pluginDisplay``")
[void]$dashboardBuilder.AppendLine()
[void]$dashboardBuilder.AppendLine("## Queue Summary")
[void]$dashboardBuilder.AppendLine()
[void]$dashboardBuilder.AppendLine("- Total: ``$($queueSummary.total)``")
[void]$dashboardBuilder.AppendLine("- Pending: ``$($queueSummary.pending)``")
[void]$dashboardBuilder.AppendLine("- In progress: ``$($queueSummary.inProgress)``")
[void]$dashboardBuilder.AppendLine("- Done: ``$($queueSummary.done)``")
[void]$dashboardBuilder.AppendLine("- Failed: ``$($queueSummary.failed)``")
[void]$dashboardBuilder.AppendLine("- Blocked: ``$($queueSummary.blocked)``")
[void]$dashboardBuilder.AppendLine("- Current stage: ``$($queueSummary.currentStage)``")
[void]$dashboardBuilder.AppendLine()
[void]$dashboardBuilder.AppendLine("## Git Status")
[void]$dashboardBuilder.AppendLine()
[void]$dashboardBuilder.AppendLine('```text')
[void]$dashboardBuilder.AppendLine($gitStatus)
[void]$dashboardBuilder.AppendLine('```')
[void]$dashboardBuilder.AppendLine()
[void]$dashboardBuilder.AppendLine("## Git Diff Stat")
[void]$dashboardBuilder.AppendLine()
[void]$dashboardBuilder.AppendLine('```text')
[void]$dashboardBuilder.AppendLine($gitDiffStat)
[void]$dashboardBuilder.AppendLine('```')
[void]$dashboardBuilder.AppendLine()
[void]$dashboardBuilder.AppendLine("## WinCC Plugin Routing Excerpt")
[void]$dashboardBuilder.AppendLine()
[void]$dashboardBuilder.AppendLine('```json')
[void]$dashboardBuilder.AppendLine($pluginText)
[void]$dashboardBuilder.AppendLine('```')
[void]$dashboardBuilder.AppendLine()
[void]$dashboardBuilder.AppendLine("## Safety Gates")
[void]$dashboardBuilder.AppendLine()
[void]$dashboardBuilder.AppendLine("- Release approval status: ``$approvalStatus`` (``$approvedFor``)")
[void]$dashboardBuilder.AppendLine("- Production writes remain disabled unless explicitly requested.")
[void]$dashboardBuilder.AppendLine("- First imports must run on backup or clone projects.")
[void]$dashboardBuilder.AppendLine("- Runtime HMI writes and alarm acknowledgement stay disabled unless explicitly requested.")
[void]$dashboardBuilder.AppendLine("- Agent queue stages should be reviewed through evidence before release.")
if ([string]::IsNullOrWhiteSpace($dashboardMd)) { throw "Dashboard output path was not resolved." }
$dashboardBuilder.ToString() | Set-Content -LiteralPath $dashboardMd -Encoding UTF8

$planValue = if (-not [string]::IsNullOrWhiteSpace($planMd) -and (Test-Path -LiteralPath $planMd -PathType Leaf)) { $planMd } else { "" }
$queueValue = if (-not [string]::IsNullOrWhiteSpace($queueJson) -and (Test-Path -LiteralPath $queueJson -PathType Leaf)) { $queueJson } else { "" }
$pluginRoutingValue = if (-not [string]::IsNullOrWhiteSpace($pluginRouting) -and (Test-Path -LiteralPath $pluginRouting -PathType Leaf)) { $pluginRouting } else { "" }
$readinessValue = if (-not [string]::IsNullOrWhiteSpace($readinessPath) -and (Test-Path -LiteralPath $readinessPath -PathType Leaf)) { $readinessPath } else { "" }
$instructionRouteValue = if (-not [string]::IsNullOrWhiteSpace($instructionRoute) -and (Test-Path -LiteralPath $instructionRoute -PathType Leaf)) { $instructionRoute } else { "" }
$instructionCookbookValue = if (-not [string]::IsNullOrWhiteSpace($instructionCookbook) -and (Test-Path -LiteralPath $instructionCookbook -PathType Leaf)) { $instructionCookbook } else { "" }
$safetyRiskValue = if (-not [string]::IsNullOrWhiteSpace($safetyRisk) -and (Test-Path -LiteralPath $safetyRisk -PathType Leaf)) { $safetyRisk } else { "" }
$winccComponentBlueprintValue = if (-not [string]::IsNullOrWhiteSpace($winccComponentBlueprints) -and (Test-Path -LiteralPath $winccComponentBlueprints -PathType Leaf)) { $winccComponentBlueprints } else { "" }
$winccEngineeringScaffoldValue = if (-not [string]::IsNullOrWhiteSpace($winccEngineeringScaffold) -and (Test-Path -LiteralPath $winccEngineeringScaffold -PathType Leaf)) { $winccEngineeringScaffold } else { "" }
$winccOpennessImplementationValue = if (-not [string]::IsNullOrWhiteSpace($winccOpennessImplementation) -and (Test-Path -LiteralPath $winccOpennessImplementation -PathType Leaf)) { $winccOpennessImplementation } else { "" }
$winccReadbackValue = if (-not [string]::IsNullOrWhiteSpace($winccReadback) -and (Test-Path -LiteralPath $winccReadback -PathType Leaf)) { $winccReadback } else { "" }
$winccImplementationRunValue = if (-not [string]::IsNullOrWhiteSpace($winccImplementationRunPath) -and (Test-Path -LiteralPath $winccImplementationRunPath -PathType Leaf)) { $winccImplementationRunPath } else { "" }
$simulationPackageValue = if (-not [string]::IsNullOrWhiteSpace($simulationPackage) -and (Test-Path -LiteralPath $simulationPackage -PathType Leaf)) { $simulationPackage } else { "" }
$simulationReplayValue = if (-not [string]::IsNullOrWhiteSpace($simulationReplay) -and (Test-Path -LiteralPath $simulationReplay -PathType Leaf)) { $simulationReplay } else { "" }
$pipelineSummaryValue = if (-not [string]::IsNullOrWhiteSpace($pipelineSummary) -and (Test-Path -LiteralPath $pipelineSummary -PathType Leaf)) { $pipelineSummary } else { "" }
$pipelineSummaryJsonValue = if (-not [string]::IsNullOrWhiteSpace($pipelineSummaryJson) -and (Test-Path -LiteralPath $pipelineSummaryJson -PathType Leaf)) { $pipelineSummaryJson } else { "" }
$projectModelValue = if (-not [string]::IsNullOrWhiteSpace($projectModel) -and (Test-Path -LiteralPath $projectModel -PathType Leaf)) { $projectModel } else { "" }
$agentContextValue = if (-not [string]::IsNullOrWhiteSpace($agentContext) -and (Test-Path -LiteralPath $agentContext -PathType Leaf)) { $agentContext } else { "" }
$knowledgeBriefValue = if (-not [string]::IsNullOrWhiteSpace($knowledgeBrief) -and (Test-Path -LiteralPath $knowledgeBrief -PathType Leaf)) { $knowledgeBrief } else { "" }
$knowledgePackValue = if (-not [string]::IsNullOrWhiteSpace($knowledgePack) -and (Test-Path -LiteralPath $knowledgePack -PathType Leaf)) { $knowledgePack } else { "" }
$capabilityMapValue = if (-not [string]::IsNullOrWhiteSpace($capabilityMap) -and (Test-Path -LiteralPath $capabilityMap -PathType Leaf)) { $capabilityMap } else { "" }
$capabilityJsonValue = if (-not [string]::IsNullOrWhiteSpace($capabilityJson) -and (Test-Path -LiteralPath $capabilityJson -PathType Leaf)) { $capabilityJson } else { "" }

$json = [pscustomobject]@{
    status = "ok"
    generatedAt = (Get-Date).ToString("o")
    projectRoot = $root
    outputDirectory = $OutputDirectory
    dashboard = $dashboardMd
    validation = $validationMd
    diff = $diffPath
    plan = $planValue
    queue = $queueValue
    pluginRouting = $pluginRoutingValue
    importReadiness = $readinessValue
    releaseApproval = if (Test-Path -LiteralPath $approvalPath -PathType Leaf) { $approvalPath } else { "" }
    releaseApprovalStatus = $approvalStatus
    releaseApprovedFor = $approvedFor
    instructionRoute = $instructionRouteValue
    instructionCookbook = $instructionCookbookValue
    safetyRisk = $safetyRiskValue
    winccComponentBlueprints = $winccComponentBlueprintValue
    winccEngineeringScaffold = $winccEngineeringScaffoldValue
    winccOpennessImplementation = $winccOpennessImplementationValue
    winccReadback = $winccReadbackValue
    winccImplementationRun = $winccImplementationRunValue
    simulationPackage = $simulationPackageValue
    simulationReplay = $simulationReplayValue
    pipelineSummary = $pipelineSummaryValue
    pipelineSummaryJson = $pipelineSummaryJsonValue
    projectModel = $projectModelValue
    agentContext = $agentContextValue
    knowledgeBrief = $knowledgeBriefValue
    knowledgePack = $knowledgePackValue
    capabilityMap = $capabilityMapValue
    capabilityJson = $capabilityJsonValue
    queueSummary = $queueSummary
}
$jsonPath = Join-Path $OutputDirectory "dashboard.json"
$json | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
$json | ConvertTo-Json -Depth 8
