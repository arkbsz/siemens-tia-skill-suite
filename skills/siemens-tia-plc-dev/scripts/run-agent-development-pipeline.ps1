param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    [string]$WorkflowConfigPath = "",
    [string]$TaskText = "",
    [string]$ReferenceImagePath = "",
    [string]$SourceXml = "",
    [string]$OutputDirectory = "",
    [switch]$RefreshWinccCatalog,
    [switch]$SkipAgentQueue
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

function Test-Any {
    param([string]$Text, [string[]]$Needles)
    foreach ($needle in $Needles) {
        if ($Text.IndexOf($needle, [StringComparison]::OrdinalIgnoreCase) -ge 0) { return $true }
    }
    return $false
}

function Invoke-Step {
    param(
        [System.Collections.Generic.List[object]]$Steps,
        [string]$Name,
        [string]$Command,
        [string[]]$Arguments,
        [string]$ExpectedOutput = "",
        [switch]$Optional
    )

    $start = Get-Date
    $stdout = Join-Path $logDir (($Name -replace '[^\w\.-]+', '_') + ".stdout.log")
    $stderr = Join-Path $logDir (($Name -replace '[^\w\.-]+', '_') + ".stderr.log")
    $status = "ok"
    $exitCode = 0
    $errorText = ""

    try {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Command @Arguments > $stdout 2> $stderr
        $exitCode = $LASTEXITCODE
        if ($exitCode -ne 0) {
            $status = if ($Optional) { "warning" } else { "failed" }
            $errorText = Get-Content -LiteralPath $stderr -Raw -ErrorAction SilentlyContinue
            if (-not $Optional) {
                throw "Step failed: $Name. ExitCode=$exitCode. $errorText"
            }
        }
    }
    catch {
        $status = if ($Optional) { "warning" } else { "failed" }
        $errorText = $_.Exception.Message
        if (-not $Optional) {
            [void]$Steps.Add([pscustomobject]@{
                name = $Name
                status = $status
                exitCode = $exitCode
                startedAt = $start.ToString("o")
                finishedAt = (Get-Date).ToString("o")
                stdout = $stdout
                stderr = $stderr
                expectedOutput = $ExpectedOutput
                error = $errorText
            })
            throw
        }
    }

    [void]$Steps.Add([pscustomobject]@{
        name = $Name
        status = $status
        exitCode = $exitCode
        startedAt = $start.ToString("o")
        finishedAt = (Get-Date).ToString("o")
        stdout = $stdout
        stderr = $stderr
        expectedOutput = $ExpectedOutput
        error = $errorText
    })
}

$root = Resolve-ProjectDirectory -Path $ProjectPath
$workspaceRoot = Join-Path $root "PLC_Code"
if ([string]::IsNullOrWhiteSpace($WorkflowConfigPath)) { $WorkflowConfigPath = Join-Path $workspaceRoot "config\ai-workflow.json" }
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $workspaceRoot ("workbench\pipelines\" + (Get-Date -Format "yyyyMMdd-HHmmss"))
}
$latestDir = Join-Path $workspaceRoot "workbench\pipelines\latest"
$logDir = Join-Path $OutputDirectory "logs"
New-Item -ItemType Directory -Path $OutputDirectory, $latestDir, $logDir -Force | Out-Null

$task = if ([string]::IsNullOrWhiteSpace($TaskText)) { "读取项目结构，生成 PLC/WinCC 自动开发计划、验证门槛和安全风险清单。" } else { $TaskText }
$taskForRoute = $task + " " + $ReferenceImagePath
$winccNeeded = Test-Any -Text $taskForRoute -Needles @("wincc", "hmi", "画面", "界面", "参考图", "截图", "复刻", "faceplate", "报警画面", "趋势")
$advancedPlcNeeded = Test-Any -Text $taskForRoute -Needles @("lad", "梯形图", "程序", "数据块", "db", "工艺对象", "motion", "pid", "modbus", "通信", "伺服", "变频", "模拟量", "报警", "互锁", "顺控")

$steps = New-Object System.Collections.Generic.List[object]
$invokeScript = Join-Path $PSScriptRoot "invoke-siemens-plc-dev.ps1"

Invoke-Step -Steps $steps -Name "project-model" -Command $invokeScript -Arguments @("project-model", "-ProjectPath", $root, "-WorkflowConfigPath", $WorkflowConfigPath, "-TaskText", $task) -ExpectedOutput "PLC_Code\workbench\context\latest"

Invoke-Step -Steps $steps -Name "knowledge-pack" -Command $invokeScript -Arguments @("knowledge-pack", "-ProjectPath", $root, "-WorkflowConfigPath", $WorkflowConfigPath, "-TaskText", $task, "-RefreshOnline") -ExpectedOutput "PLC_Code\knowledge\packs\latest"

Invoke-Step -Steps $steps -Name "capability-map" -Command $invokeScript -Arguments @("capability-map", "-ProjectPath", $root, "-WorkflowConfigPath", $WorkflowConfigPath, "-TaskText", $task) -ExpectedOutput "PLC_Code\workbench\capabilities\latest"

if ($advancedPlcNeeded) {
    Invoke-Step -Steps $steps -Name "plc-instruction-cookbook" -Command $invokeScript -Arguments @("plc-instruction-cookbook", "-ProjectPath", $root, "-WorkflowConfigPath", $WorkflowConfigPath, "-TaskText", $task) -ExpectedOutput "PLC_Code\plc\instruction-cookbook\latest"

    $args = @("plc-instruction-plan", "-ProjectPath", $root, "-WorkflowConfigPath", $WorkflowConfigPath, "-TaskText", $task)
    if ((-not [string]::IsNullOrWhiteSpace($SourceXml)) -and (Test-Path -LiteralPath $SourceXml -PathType Leaf)) {
        $args += @("-SourceXml", (Get-Item -LiteralPath $SourceXml).FullName)
    }
    Invoke-Step -Steps $steps -Name "plc-instruction-plan" -Command $invokeScript -Arguments $args -ExpectedOutput "PLC_Code\plc\instruction-plans\latest"
}

if ($winccNeeded) {
    $pluginArgs = @("wincc-plugins", "-ProjectPath", $root, "-WorkflowConfigPath", $WorkflowConfigPath, "-TaskText", $task)
    if ($RefreshWinccCatalog) { $pluginArgs += "-RefreshCatalog" }
    if ((-not [string]::IsNullOrWhiteSpace($ReferenceImagePath)) -and (Test-Path -LiteralPath $ReferenceImagePath -PathType Leaf)) {
        $pluginArgs += @("-ReferenceImagePath", (Get-Item -LiteralPath $ReferenceImagePath).FullName)
    }
    Invoke-Step -Steps $steps -Name "wincc-plugin-routing" -Command $invokeScript -Arguments $pluginArgs -ExpectedOutput "PLC_Code\wincc\plugin-routing.json" -Optional

    $visualArgs = @("wincc-visual-package", "-ProjectPath", $root, "-WorkflowConfigPath", $WorkflowConfigPath, "-TaskText", $task)
    if ((-not [string]::IsNullOrWhiteSpace($ReferenceImagePath)) -and (Test-Path -LiteralPath $ReferenceImagePath -PathType Leaf)) {
        $visualArgs += @("-ReferenceImagePath", (Get-Item -LiteralPath $ReferenceImagePath).FullName)
    }
    Invoke-Step -Steps $steps -Name "wincc-visual-package" -Command $invokeScript -Arguments $visualArgs -ExpectedOutput "PLC_Code\wincc\tasks\latest"

    $blueprintArgs = @("wincc-component-blueprints", "-ProjectPath", $root, "-WorkflowConfigPath", $WorkflowConfigPath, "-TaskText", $task)
    if ((-not [string]::IsNullOrWhiteSpace($ReferenceImagePath)) -and (Test-Path -LiteralPath $ReferenceImagePath -PathType Leaf)) {
        $blueprintArgs += @("-ReferenceImagePath", (Get-Item -LiteralPath $ReferenceImagePath).FullName)
    }
    Invoke-Step -Steps $steps -Name "wincc-component-blueprints" -Command $invokeScript -Arguments $blueprintArgs -ExpectedOutput "PLC_Code\wincc\component-blueprints\latest"

    $engineeringArgs = @("wincc-engineering-scaffold", "-ProjectPath", $root, "-WorkflowConfigPath", $WorkflowConfigPath, "-TaskText", $task)
    if ((-not [string]::IsNullOrWhiteSpace($ReferenceImagePath)) -and (Test-Path -LiteralPath $ReferenceImagePath -PathType Leaf)) {
        $engineeringArgs += @("-ReferenceImagePath", (Get-Item -LiteralPath $ReferenceImagePath).FullName)
    }
    Invoke-Step -Steps $steps -Name "wincc-engineering-scaffold" -Command $invokeScript -Arguments $engineeringArgs -ExpectedOutput "PLC_Code\wincc\engineering-scaffold\latest"
}

$simulationArgs = @("simulation-package", "-ProjectPath", $root, "-WorkflowConfigPath", $WorkflowConfigPath, "-TaskText", $task)
Invoke-Step -Steps $steps -Name "simulation-package" -Command $invokeScript -Arguments $simulationArgs -ExpectedOutput "PLC_Code\simulation\latest"

$workflow = if ($winccNeeded -and $advancedPlcNeeded) { "agent-workbench" } elseif ($winccNeeded) { "wincc-visual" } elseif ($advancedPlcNeeded) { "advanced-plc" } else { "project-read" }
$planArgs = @("agent-plan", "-ProjectPath", $root, "-WorkflowConfigPath", $WorkflowConfigPath, "-TaskText", $task, "-Workflow", $workflow, "-AgentId", "workbench")
if ((-not [string]::IsNullOrWhiteSpace($ReferenceImagePath)) -and (Test-Path -LiteralPath $ReferenceImagePath -PathType Leaf)) {
    $planArgs += @("-ReferenceImagePath", (Get-Item -LiteralPath $ReferenceImagePath).FullName)
}
Invoke-Step -Steps $steps -Name "agent-plan" -Command $invokeScript -Arguments $planArgs -ExpectedOutput "PLC_Code\agent-plans\latest-plan.md"

if (-not $SkipAgentQueue) {
    $planJson = Join-Path $workspaceRoot "agent-plans\latest-plan.json"
    $queueArgs = @("agent-queue", "-ProjectPath", $root, "-WorkflowConfigPath", $WorkflowConfigPath, "-TaskText", $task)
    if (Test-Path -LiteralPath $planJson -PathType Leaf) {
        $queueArgs += @("-PlanPath", $planJson)
    }
    Invoke-Step -Steps $steps -Name "agent-queue" -Command $invokeScript -Arguments $queueArgs -ExpectedOutput "PLC_Code\agent-queues\latest\queue.md"
}

Invoke-Step -Steps $steps -Name "workbench-dashboard" -Command $invokeScript -Arguments @("workbench-dashboard", "-ProjectPath", $root, "-WorkflowConfigPath", $WorkflowConfigPath) -ExpectedOutput "PLC_Code\workbench\latest\dashboard.md"

$summary = [pscustomobject]@{
    status = "ok"
    generatedAt = (Get-Date).ToString("o")
    projectRoot = $root
    taskText = $task
    workflow = $workflow
    winccNeeded = $winccNeeded
    advancedPlcNeeded = $advancedPlcNeeded
    outputDirectory = $OutputDirectory
    latestDirectory = $latestDir
    steps = @($steps.ToArray())
    releaseAllowed = $false
}
$summaryPath = Join-Path $OutputDirectory "pipeline-summary.json"
$latestSummaryPath = Join-Path $latestDir "pipeline-summary.json"
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $latestSummaryPath -Encoding UTF8

$md = New-Object System.Text.StringBuilder
[void]$md.AppendLine("# Agent Development Pipeline")
[void]$md.AppendLine()
[void]$md.AppendLine("- Project: ``$root``")
[void]$md.AppendLine("- Workflow: ``$workflow``")
[void]$md.AppendLine("- WinCC needed: ``$winccNeeded``")
[void]$md.AppendLine("- Advanced PLC needed: ``$advancedPlcNeeded``")
[void]$md.AppendLine("- Release allowed: ``false``")
[void]$md.AppendLine()
[void]$md.AppendLine("## Task")
[void]$md.AppendLine()
[void]$md.AppendLine($task)
[void]$md.AppendLine()
[void]$md.AppendLine("## Steps")
[void]$md.AppendLine()
foreach ($step in $steps) {
    [void]$md.AppendLine("- " + $step.name + ": " + $step.status + " -> " + $step.expectedOutput)
}
[void]$md.AppendLine()
[void]$md.AppendLine("## Next Review Files")
[void]$md.AppendLine()
[void]$md.AppendLine("- PLC_Code\workbench\context\latest\agent-context.md")
[void]$md.AppendLine("- PLC_Code\workbench\context\latest\project-model.json")
[void]$md.AppendLine("- PLC_Code\knowledge\packs\latest\knowledge-brief.md")
[void]$md.AppendLine("- PLC_Code\workbench\capabilities\latest\capability-map.md")
[void]$md.AppendLine("- PLC_Code\workbench\latest\dashboard.md")
[void]$md.AppendLine("- PLC_Code\plc\instruction-cookbook\latest\instruction-cookbook.md")
[void]$md.AppendLine("- PLC_Code\plc\instruction-plans\latest\instruction-route-table.md")
[void]$md.AppendLine("- PLC_Code\wincc\tasks\latest\implementation-plan.md")
[void]$md.AppendLine("- PLC_Code\wincc\component-blueprints\latest\component-blueprints.md")
[void]$md.AppendLine("- PLC_Code\wincc\engineering-scaffold\latest\wincc-engineering-scaffold.md")
[void]$md.AppendLine("- PLC_Code\simulation\latest\simulation-package.md")
[void]$md.AppendLine("- PLC_Code\agent-plans\latest-plan.md")
[void]$md.AppendLine("- PLC_Code\agent-queues\latest\queue.md")
[void]$md.AppendLine()
[void]$md.AppendLine("Production import/download is intentionally outside this pipeline. Use release gates after clone compile and human review.")
$summaryMdPath = Join-Path $OutputDirectory "pipeline-summary.md"
$latestSummaryMdPath = Join-Path $latestDir "pipeline-summary.md"
$md.ToString() | Set-Content -LiteralPath $summaryMdPath -Encoding UTF8
$md.ToString() | Set-Content -LiteralPath $latestSummaryMdPath -Encoding UTF8

try {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $invokeScript @("workbench-dashboard", "-ProjectPath", $root, "-WorkflowConfigPath", $WorkflowConfigPath) | Out-Null
}
catch {
    [void]$steps.Add([pscustomobject]@{
        name = "workbench-dashboard-final-refresh"
        status = "warning"
        exitCode = 1
        startedAt = (Get-Date).ToString("o")
        finishedAt = (Get-Date).ToString("o")
        stdout = ""
        stderr = ""
        expectedOutput = "PLC_Code\workbench\latest\dashboard.md"
        error = $_.Exception.Message
    })
}

$summary | Add-Member -NotePropertyName summary -NotePropertyValue $summaryMdPath
$summary | Add-Member -NotePropertyName summaryJson -NotePropertyValue $summaryPath
$summary | ConvertTo-Json -Depth 8
