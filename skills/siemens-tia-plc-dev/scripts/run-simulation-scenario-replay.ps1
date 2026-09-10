param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    [string]$WorkflowConfigPath = "",
    [string]$SimulationPackagePath = "",
    [string]$ScenarioId = "",
    [string]$OutputDirectory = "",
    [switch]$Strict
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

function Test-PathText {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    return Test-Path -LiteralPath $Path
}

function Add-Result {
    param(
        $Items,
        [string]$Id,
        [string]$Name,
        [string]$Status,
        [string]$Evidence,
        [string]$Notes
    )
    [void]$Items.Add([pscustomobject]@{
        id = $Id
        name = $Name
        status = $Status
        evidence = $Evidence
        notes = $Notes
    })
}

$root = Resolve-ProjectDirectory -Path $ProjectPath
$workspaceRoot = Join-Path $root "PLC_Code"
if ([string]::IsNullOrWhiteSpace($WorkflowConfigPath)) { $WorkflowConfigPath = Join-Path $workspaceRoot "config\ai-workflow.json" }
if ([string]::IsNullOrWhiteSpace($SimulationPackagePath)) { $SimulationPackagePath = Join-Path $workspaceRoot "simulation\latest\simulation-package.json" }
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $workspaceRoot ("simulation\replays\" + (Get-Date -Format "yyyyMMdd-HHmmss"))
}
$latestDir = Join-Path $workspaceRoot "simulation\replays\latest"
New-Item -ItemType Directory -Path $OutputDirectory, $latestDir -Force | Out-Null

if (-not (Test-Path -LiteralPath $SimulationPackagePath -PathType Leaf)) {
    throw "Simulation package was not found. Run simulation-package first: $SimulationPackagePath"
}

$package = Get-Content -LiteralPath $SimulationPackagePath -Raw -Encoding UTF8 | ConvertFrom-Json
$scenarios = @($package.scenarios)
if (-not [string]::IsNullOrWhiteSpace($ScenarioId)) {
    $scenarios = @($scenarios | Where-Object { [string]$_.id -eq $ScenarioId })
}
if ($scenarios.Count -eq 0) {
    throw "No scenarios matched '$ScenarioId'."
}

$projectModel = Join-Path $workspaceRoot "workbench\context\latest\project-model.json"
$instructionPlan = Join-Path $workspaceRoot "plc\instruction-plans\latest\instruction-route-table.md"
$winccScaffold = Join-Path $workspaceRoot "wincc\engineering-scaffold\latest\wincc-engineering-scaffold.json"
$reviewReadiness = Join-Path $workspaceRoot "review-packages\latest\import-readiness.json"
$writeRun = Get-ChildItem -LiteralPath (Join-Path $workspaceRoot "runs") -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "write-cycle*" } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

$config = $null
if (Test-Path -LiteralPath $WorkflowConfigPath -PathType Leaf) {
    $config = Get-Content -LiteralPath $WorkflowConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
}
$graphqlUrl = ""
if ($config -and $config.PSObject.Properties["wincc"] -and $config.wincc.PSObject.Properties["graphqlUrl"]) {
    $graphqlUrl = [string]$config.wincc.graphqlUrl
}

$results = New-Object System.Collections.ArrayList
foreach ($scenario in $scenarios) {
    $id = [string]$scenario.id
    $name = [string]$scenario.name
    $status = "READY_FOR_REVIEW"
    $evidence = ""
    $notes = "离线场景已回放为检查项，等待真实 Openness/PLCSIM/Runtime 证据。"

    if ($id -eq "compile-clone") {
        if ($writeRun) {
            $status = "EVIDENCE_FOUND"
            $evidence = $writeRun.FullName
            $notes = "已找到最近 write-cycle，可作为克隆编译证据入口。"
        }
        else {
            $status = if ($Strict) { "MISSING_EVIDENCE" } else { "READY_FOR_CLONE_COMPILE" }
            $notes = "未找到 write-cycle 证据；下一步运行 write-cycle 或 compile-plc on clone。"
        }
    }
    elseif ($id -eq "wincc-runtime-smoke") {
        if (-not [string]::IsNullOrWhiteSpace($graphqlUrl)) {
            $status = "READY_FOR_GRAPHQL_SMOKE"
            $evidence = $WorkflowConfigPath
            $notes = "已配置 GraphQL endpoint；默认只读 query/subscribe，写入需明确授权。"
        }
        else {
            $status = if ($Strict) { "CONFIG_REQUIRED" } else { "READY_FOR_MANUAL_SMOKE" }
            $notes = "未配置 GraphQL endpoint；保留为人工或后续 runtime MCP 冒烟检查。"
        }
    }
    elseif ($id -eq "drive-comm") {
        $status = if (Test-PathText $instructionPlan) { "READY_FOR_TAG_TRACE" } else { "NEEDS_INSTRUCTION_PLAN" }
        $evidence = if (Test-PathText $instructionPlan) { $instructionPlan } else { "" }
        $notes = "重点检查 BUSY/DONE/ERROR/STATUS、陈旧数据和速度设定反馈。"
    }
    elseif ($id -eq "manual-auto-mode" -or $id -eq "interlock-fault" -or $id -eq "sequence-cycle") {
        $status = if (Test-PathText $projectModel) { "READY_FOR_IO_TABLE" } else { "NEEDS_PROJECT_MODEL" }
        $evidence = if (Test-PathText $projectModel) { $projectModel } else { "" }
        $notes = "按项目模型和 DB/HMI 契约生成 I/O 表后，可交给 PLCSIM 或人工仿真执行。"
    }

    Add-Result $results $id $name $status $evidence $notes
}

$summary = [pscustomobject]@{
    schemaVersion = 1
    generatedAt = (Get-Date).ToString("o")
    projectRoot = $root
    workflowConfigPath = $WorkflowConfigPath
    simulationPackagePath = $SimulationPackagePath
    strict = [bool]$Strict
    plcsimDetected = [bool]$package.plcsimAdvanced.detected
    inputs = [pscustomobject]@{
        projectModel = if (Test-PathText $projectModel) { $projectModel } else { "" }
        instructionPlan = if (Test-PathText $instructionPlan) { $instructionPlan } else { "" }
        winccEngineeringScaffold = if (Test-PathText $winccScaffold) { $winccScaffold } else { "" }
        reviewReadiness = if (Test-PathText $reviewReadiness) { $reviewReadiness } else { "" }
        latestWriteCycle = if ($writeRun) { $writeRun.FullName } else { "" }
        graphqlUrlConfigured = (-not [string]::IsNullOrWhiteSpace($graphqlUrl))
    }
    results = @($results)
    releaseAllowed = $false
}

$jsonPath = Join-Path $OutputDirectory "replay-report.json"
$latestJsonPath = Join-Path $latestDir "replay-report.json"
$summary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
$summary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $latestJsonPath -Encoding UTF8

$csvPath = Join-Path $OutputDirectory "scenario-results.csv"
$latestCsvPath = Join-Path $latestDir "scenario-results.csv"
@($results) | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8
@($results) | Export-Csv -LiteralPath $latestCsvPath -NoTypeInformation -Encoding UTF8

$md = New-Object System.Text.StringBuilder
[void]$md.AppendLine("# Simulation Scenario Replay")
[void]$md.AppendLine()
[void]$md.AppendLine("- Project: ``$root``")
[void]$md.AppendLine("- Package: ``$SimulationPackagePath``")
[void]$md.AppendLine("- PLCSIM Advanced detected: ``$($summary.plcsimDetected)``")
[void]$md.AppendLine("- Strict mode: ``$Strict``")
[void]$md.AppendLine("- Release allowed: ``false``")
[void]$md.AppendLine("- Generated: ``$(Get-Date -Format o)``")
[void]$md.AppendLine()
[void]$md.AppendLine("## Results")
[void]$md.AppendLine()
foreach ($result in $results) {
    [void]$md.AppendLine("### " + $result.name)
    [void]$md.AppendLine("- Status: " + $result.status)
    [void]$md.AppendLine("- Evidence: " + $result.evidence)
    [void]$md.AppendLine("- Notes: " + $result.notes)
    [void]$md.AppendLine()
}
[void]$md.AppendLine("## Next Execution Route")
[void]$md.AppendLine()
[void]$md.AppendLine("1. For `READY_FOR_CLONE_COMPILE`, run `write-cycle` or `compile-plc` on a clone.")
[void]$md.AppendLine("2. For `READY_FOR_IO_TABLE`, map scenario inputs to PLC tags and run PLCSIM Advanced if available.")
[void]$md.AppendLine("3. For `READY_FOR_GRAPHQL_SMOKE`, run read-only WinCC Unified GraphQL query/subscribe tests on a trusted endpoint.")
[void]$md.AppendLine("4. Keep hardware download, alarm acknowledgement and command writes behind explicit user intent.")

$mdPath = Join-Path $OutputDirectory "replay-report.md"
$latestMdPath = Join-Path $latestDir "replay-report.md"
$md.ToString() | Set-Content -LiteralPath $mdPath -Encoding UTF8
$md.ToString() | Set-Content -LiteralPath $latestMdPath -Encoding UTF8

[pscustomobject]@{
    status = "ok"
    outputDirectory = $OutputDirectory
    latestDirectory = $latestDir
    report = $mdPath
    reportJson = $jsonPath
    resultCount = $results.Count
    plcsimDetected = $summary.plcsimDetected
    releaseAllowed = $false
} | ConvertTo-Json -Depth 6
