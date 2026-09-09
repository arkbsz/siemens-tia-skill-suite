param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    [string]$WorkflowConfigPath = "",
    [string]$TaskText = "",
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
    param([string]$Path, [int]$Max = 5000)
    if ([string]::IsNullOrWhiteSpace($Path)) { return "" }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return "" }
    $text = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($null -eq $text) { return "" }
    if ($text.Length -gt $Max) { return $text.Substring(0, $Max) + "`r`n... truncated ..." }
    return $text
}

function Get-LatestFile {
    param([string]$Root, [string]$Filter)
    if (-not (Test-Path -LiteralPath $Root -PathType Container)) { return "" }
    $file = Get-ChildItem -LiteralPath $Root -Recurse -File -Filter $Filter -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($file) { return $file.FullName }
    return ""
}

function Get-LatestDirectory {
    param([string]$Root)
    if (-not (Test-Path -LiteralPath $Root -PathType Container)) { return "" }
    $dir = Get-ChildItem -LiteralPath $Root -Directory -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($dir) { return $dir.FullName }
    return ""
}

function Parse-BlockList {
    param([string]$Path)
    $blocks = New-Object System.Collections.Generic.List[object]
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return @() }
    $lines = Get-Content -LiteralPath $Path -Encoding UTF8
    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line.StartsWith("#") -or $line.StartsWith("Name`t") -or $line.StartsWith("STARTING`t") -or $line.StartsWith("OPENING`t") -or $line.StartsWith("OPENED`t")) { continue }
        $parts = $line -split "`t"
        if ($parts.Count -lt 4) { continue }
        [void]$blocks.Add([pscustomobject]@{
            name = $parts[0]
            type = $parts[1]
            number = $parts[2]
            language = $parts[3]
            group = $(if ($parts.Count -gt 4) { $parts[4] } else { "" })
            consistent = $(if ($parts.Count -gt 5) { $parts[5] } else { "" })
            knowHowProtected = $(if ($parts.Count -gt 6) { $parts[6] } else { "" })
        })
    }
    return @($blocks.ToArray())
}

function Infer-ProjectVersion {
    param([string]$Root)
    $projectFile = Get-ChildItem -LiteralPath $Root -File -Include "*.ap16","*.ap17","*.ap18","*.ap19","*.ap20","*.ap21" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if (-not $projectFile) { return [pscustomobject]@{ version = ""; projectFile = "" } }
    $match = [regex]::Match($projectFile.Extension, "\.ap(?<v>\d+)", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    return [pscustomobject]@{
        version = $(if ($match.Success) { "V" + $match.Groups["v"].Value } else { "" })
        projectFile = $projectFile.FullName
    }
}

function Classify-WorkspaceFile {
    param([System.IO.FileInfo]$File, [string]$WorkspaceRoot)
    $relative = $File.FullName.Substring($WorkspaceRoot.Length).TrimStart('\')
    $category = "other"
    if ($relative -like "exports\*") { $category = "tia-export" }
    elseif ($relative -like "ladders\*" -or $relative -like "lad-previews\*") { $category = "lad-preview" }
    elseif ($relative -like "runs\*") { $category = "run-report" }
    elseif ($relative -like "plc\instruction-plans\*") { $category = "instruction-plan" }
    elseif ($relative -like "plc\instruction-cookbook\*") { $category = "instruction-cookbook" }
    elseif ($relative -like "wincc\engineering-scaffold\*") { $category = "wincc-engineering-scaffold" }
    elseif ($relative -like "wincc\component-blueprints\*") { $category = "wincc-component-blueprint" }
    elseif ($relative -like "wincc\*") { $category = "wincc" }
    elseif ($relative -like "simulation\*") { $category = "simulation" }
    elseif ($relative -like "agent-plans\*") { $category = "agent-plan" }
    elseif ($relative -like "agent-queues\*") { $category = "agent-queue" }
    elseif ($relative -like "changes\*") { $category = "change-package" }
    elseif ($relative -like "review-packages\*") { $category = "review-package" }
    elseif ($relative -like "config\*") { $category = "config" }
    return [pscustomobject]@{
        relativePath = $relative
        category = $category
        extension = $File.Extension
        bytes = $File.Length
        lastWriteTime = $File.LastWriteTime.ToString("o")
    }
}

$root = Resolve-ProjectDirectory -Path $ProjectPath
$workspaceRoot = Join-Path $root "PLC_Code"
if ([string]::IsNullOrWhiteSpace($WorkflowConfigPath)) { $WorkflowConfigPath = Join-Path $workspaceRoot "config\ai-workflow.json" }
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $workspaceRoot ("workbench\context\" + (Get-Date -Format "yyyyMMdd-HHmmss"))
}
$latestDir = Join-Path $workspaceRoot "workbench\context\latest"
New-Item -ItemType Directory -Path $OutputDirectory, $latestDir -Force | Out-Null

$versionInfo = Infer-ProjectVersion -Root $root
$latestReadRun = Get-LatestDirectory -Root (Join-Path $workspaceRoot "runs")
$blockListPath = if ($latestReadRun) { Join-Path $latestReadRun "reports\block-list.txt" } else { "" }
$blocks = Parse-BlockList -Path $blockListPath
$latestExportRun = Get-LatestDirectory -Root (Join-Path $workspaceRoot "exports")
$latestWinccTask = Join-Path $workspaceRoot "wincc\tasks\latest"
$latestInstructionPlan = Join-Path $workspaceRoot "plc\instruction-plans\latest"
$latestQueue = Join-Path $workspaceRoot "agent-queues\latest\queue.json"
$latestDashboard = Join-Path $workspaceRoot "workbench\latest\dashboard.md"
$latestPipeline = Join-Path $workspaceRoot "workbench\pipelines\latest\pipeline-summary.md"
$latestKnowledgePack = Join-Path $workspaceRoot "knowledge\packs\latest\knowledge-brief.md"
$latestCapabilityMap = Join-Path $workspaceRoot "workbench\capabilities\latest\capability-map.md"
$latestInstructionCookbook = Join-Path $workspaceRoot "plc\instruction-cookbook\latest\instruction-cookbook.md"
$latestWinccComponentBlueprints = Join-Path $workspaceRoot "wincc\component-blueprints\latest\component-blueprints.md"
$latestWinccEngineeringScaffold = Join-Path $workspaceRoot "wincc\engineering-scaffold\latest\wincc-engineering-scaffold.md"
$latestSimulationPackage = Join-Path $workspaceRoot "simulation\latest\simulation-package.md"
$latestReview = Join-Path $workspaceRoot "review-packages\latest\review-summary.md"

$fileItems = @()
if (Test-Path -LiteralPath $workspaceRoot -PathType Container) {
    $scanRoots = @(
        $latestExportRun,
        $latestReadRun,
        (Join-Path $workspaceRoot "ladders"),
        (Join-Path $workspaceRoot "lad-previews"),
        $latestWinccTask,
        $latestInstructionPlan,
        (Join-Path $workspaceRoot "agent-plans"),
        (Join-Path $workspaceRoot "agent-queues\latest"),
        (Join-Path $workspaceRoot "knowledge\packs\latest"),
        (Join-Path $workspaceRoot "workbench\capabilities\latest"),
        (Join-Path $workspaceRoot "plc\instruction-cookbook\latest"),
        (Join-Path $workspaceRoot "wincc\component-blueprints\latest"),
        (Join-Path $workspaceRoot "wincc\engineering-scaffold\latest"),
        (Join-Path $workspaceRoot "simulation\latest"),
        (Join-Path $workspaceRoot "changes\latest-plc-change-package"),
        (Join-Path $workspaceRoot "review-packages\latest"),
        (Join-Path $workspaceRoot "config"),
        (Join-Path $workspaceRoot "verification")
    )
    $collected = New-Object System.Collections.Generic.List[System.IO.FileInfo]
    foreach ($scanRoot in $scanRoots) {
        if ([string]::IsNullOrWhiteSpace($scanRoot) -or -not (Test-Path -LiteralPath $scanRoot -PathType Container)) { continue }
        Get-ChildItem -LiteralPath $scanRoot -Recurse -File -ErrorAction SilentlyContinue |
            Select-Object -First 80 |
            ForEach-Object { [void]$collected.Add($_) }
    }
    $fileItems = $collected |
        Sort-Object FullName -Unique |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 400 |
        ForEach-Object { Classify-WorkspaceFile -File $_ -WorkspaceRoot $workspaceRoot }
}

$routePreference = if ($versionInfo.version -in @("V20", "V21")) {
    "SIMATIC SD text documents when available; Openness XML/SCL remains fallback and verification surface."
}
elseif ($versionInfo.version) {
    "Openness XML for LAD/FBD plus SCL source import; SIMATIC SD is not the primary route for this version."
}
else {
    "Unknown version: run doctor/read-cycle first, then choose XML/SCL/SD by detected TIA version."
}

$latestWinccTaskValue = ""
$latestInstructionPlanValue = ""
$latestQueueValue = ""
$latestDashboardValue = ""
$latestPipelineValue = ""
$latestKnowledgePackValue = ""
$latestCapabilityMapValue = ""
$latestInstructionCookbookValue = ""
$latestWinccComponentBlueprintsValue = ""
$latestWinccEngineeringScaffoldValue = ""
$latestSimulationPackageValue = ""
$latestReviewValue = ""
if (Test-Path -LiteralPath $latestWinccTask -PathType Container) { $latestWinccTaskValue = $latestWinccTask }
if (Test-Path -LiteralPath $latestInstructionPlan -PathType Container) { $latestInstructionPlanValue = $latestInstructionPlan }
if (Test-Path -LiteralPath $latestQueue -PathType Leaf) { $latestQueueValue = $latestQueue }
if (Test-Path -LiteralPath $latestDashboard -PathType Leaf) { $latestDashboardValue = $latestDashboard }
if (Test-Path -LiteralPath $latestPipeline -PathType Leaf) { $latestPipelineValue = $latestPipeline }
if (Test-Path -LiteralPath $latestKnowledgePack -PathType Leaf) { $latestKnowledgePackValue = $latestKnowledgePack }
if (Test-Path -LiteralPath $latestCapabilityMap -PathType Leaf) { $latestCapabilityMapValue = $latestCapabilityMap }
if (Test-Path -LiteralPath $latestInstructionCookbook -PathType Leaf) { $latestInstructionCookbookValue = $latestInstructionCookbook }
if (Test-Path -LiteralPath $latestWinccComponentBlueprints -PathType Leaf) { $latestWinccComponentBlueprintsValue = $latestWinccComponentBlueprints }
if (Test-Path -LiteralPath $latestWinccEngineeringScaffold -PathType Leaf) { $latestWinccEngineeringScaffoldValue = $latestWinccEngineeringScaffold }
if (Test-Path -LiteralPath $latestSimulationPackage -PathType Leaf) { $latestSimulationPackageValue = $latestSimulationPackage }
if (Test-Path -LiteralPath $latestReview -PathType Leaf) { $latestReviewValue = $latestReview }

$model = [pscustomobject]@{
    schemaVersion = 1
    generatedAt = (Get-Date).ToString("o")
    projectRoot = $root
    projectFile = $versionInfo.projectFile
    tiaVersion = $versionInfo.version
    workflowConfigPath = $WorkflowConfigPath
    taskText = $TaskText
    namingRule = "中文_English"
    authoringRoute = $routePreference
    blocks = @($blocks)
    counts = [pscustomobject]@{
        blocks = @($blocks).Count
        ladBlocks = @($blocks | Where-Object { $_.language -eq "LAD" }).Count
        dbBlocks = @($blocks | Where-Object { $_.type -eq "GlobalDB" }).Count
        workspaceFilesIndexed = @($fileItems).Count
    }
    latestArtifacts = [pscustomobject]@{
        blockList = $blockListPath
        latestReadRun = $latestReadRun
        latestWinccTask = $latestWinccTaskValue
        latestInstructionPlan = $latestInstructionPlanValue
        latestQueue = $latestQueueValue
        latestDashboard = $latestDashboardValue
        latestPipeline = $latestPipelineValue
        latestKnowledgePack = $latestKnowledgePackValue
        latestCapabilityMap = $latestCapabilityMapValue
        latestInstructionCookbook = $latestInstructionCookbookValue
        latestWinccComponentBlueprints = $latestWinccComponentBlueprintsValue
        latestWinccEngineeringScaffold = $latestWinccEngineeringScaffoldValue
        latestSimulationPackage = $latestSimulationPackageValue
        latestReview = $latestReviewValue
    }
    workspaceFiles = @($fileItems)
    sourceAnchors = @(
        "https://docs.tia.siemens.cloud/r/en-us/v21/tia-portal-openness-api-for-automation-of-engineering-workflows/export/import",
        "https://github.com/siemens/simatic-sd",
        "https://docs.tia.siemens.cloud/r/en-us/v21/sivarc-openness/sivarc-generation",
        "https://github.com/tia-portal-applications/CWC-in-WinCC-Unified"
    )
    releaseAllowed = $false
}

$jsonPath = Join-Path $OutputDirectory "project-model.json"
$latestJsonPath = Join-Path $latestDir "project-model.json"
$model | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
$model | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $latestJsonPath -Encoding UTF8

$csvPath = Join-Path $OutputDirectory "file-index.csv"
$latestCsvPath = Join-Path $latestDir "file-index.csv"
@($fileItems) | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8
@($fileItems) | Export-Csv -LiteralPath $latestCsvPath -NoTypeInformation -Encoding UTF8

$contextPath = Join-Path $OutputDirectory "agent-context.md"
$latestContextPath = Join-Path $latestDir "agent-context.md"
$md = New-Object System.Text.StringBuilder
[void]$md.AppendLine("# PLC Agent Context")
[void]$md.AppendLine()
[void]$md.AppendLine("- Project: ``$root``")
[void]$md.AppendLine("- Project file: ``$($versionInfo.projectFile)``")
[void]$md.AppendLine("- TIA version: ``$($versionInfo.version)``")
[void]$md.AppendLine("- Naming rule: ``中文_English``")
[void]$md.AppendLine("- Authoring route: $routePreference")
[void]$md.AppendLine("- Generated: ``$(Get-Date -Format o)``")
[void]$md.AppendLine()
[void]$md.AppendLine("## Latest Artifacts")
[void]$md.AppendLine()
foreach ($prop in $model.latestArtifacts.PSObject.Properties) {
    [void]$md.AppendLine("- " + $prop.Name + ": ``" + $prop.Value + "``")
}
[void]$md.AppendLine()
[void]$md.AppendLine("## PLC Blocks")
[void]$md.AppendLine()
[void]$md.AppendLine("| Name | Type | Number | Language | Consistent | Protected |")
[void]$md.AppendLine("| --- | --- | --- | --- | --- | --- |")
foreach ($block in $blocks) {
    [void]$md.AppendLine("| $($block.name) | $($block.type) | $($block.number) | $($block.language) | $($block.consistent) | $($block.knowHowProtected) |")
}
[void]$md.AppendLine()
[void]$md.AppendLine("## Development Rules For Agents")
[void]$md.AppendLine()
[void]$md.AppendLine("- Read this context before planning broad PLC/WinCC edits.")
[void]$md.AppendLine("- Keep maintenance-facing sequencing, interlocks, alarms, manual commands, timers and counters in LAD when practical.")
[void]$md.AppendLine("- Use generic CALL networks for technology objects, motion, communication and vendor/library blocks when their typed interfaces are exported or documented.")
[void]$md.AppendLine("- Use SCL for algorithm-heavy scaling, conversion, arrays, strings, word packing and protocol parsing.")
[void]$md.AppendLine("- Separate command, feedback, status, interlock, alarm, parameter and diagnostic tags.")
[void]$md.AppendLine("- Do not write to a production project from this context package; use clone compile, review package and explicit release gates.")
[void]$md.AppendLine()
[void]$md.AppendLine("## Source Anchors")
[void]$md.AppendLine()
foreach ($source in $model.sourceAnchors) {
    [void]$md.AppendLine("- $source")
}
[void]$md.AppendLine()
[void]$md.AppendLine("## Indexed Workspace Files")
[void]$md.AppendLine()
[void]$md.AppendLine("See ``file-index.csv`` and ``project-model.json`` for the full machine-readable context.")
$md.ToString() | Set-Content -LiteralPath $contextPath -Encoding UTF8
$md.ToString() | Set-Content -LiteralPath $latestContextPath -Encoding UTF8

[pscustomobject]@{
    status = "ok"
    outputDirectory = $OutputDirectory
    latestDirectory = $latestDir
    projectModel = $jsonPath
    agentContext = $contextPath
    fileIndex = $csvPath
    blockCount = @($blocks).Count
    tiaVersion = $versionInfo.version
} | ConvertTo-Json -Depth 6
