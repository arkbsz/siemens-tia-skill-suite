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
    param([string]$Path, [int]$Max = 3000)
    if ([string]::IsNullOrWhiteSpace($Path)) { return "" }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return "" }
    $text = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($null -eq $text) { return "" }
    if ($text.Length -gt $Max) { return $text.Substring(0, $Max) + "`r`n... truncated ..." }
    return $text
}

function Find-FirstExistingPath {
    param([string[]]$Candidates)
    foreach ($candidate in $Candidates) {
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    return ""
}

function Add-Scenario {
    param(
        $Items,
        [string]$Id,
        [string]$Name,
        [string]$Stimulus,
        [string]$Expected,
        [string]$Evidence,
        [string]$Risk
    )
    [void]$Items.Add([pscustomobject]@{
        id = $Id
        name = $Name
        stimulus = $Stimulus
        expected = $Expected
        evidence = $Evidence
        risk = $Risk
    })
}

$root = Resolve-ProjectDirectory -Path $ProjectPath
$workspaceRoot = Join-Path $root "PLC_Code"
if ([string]::IsNullOrWhiteSpace($WorkflowConfigPath)) { $WorkflowConfigPath = Join-Path $workspaceRoot "config\ai-workflow.json" }
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $workspaceRoot ("simulation\packages\" + (Get-Date -Format "yyyyMMdd-HHmmss"))
}
$latestDir = Join-Path $workspaceRoot "simulation\latest"
New-Item -ItemType Directory -Path $OutputDirectory, $latestDir -Force | Out-Null

$projectModelPath = Join-Path $workspaceRoot "workbench\context\latest\project-model.json"
$agentContextPath = Join-Path $workspaceRoot "workbench\context\latest\agent-context.md"
$instructionPlanPath = Join-Path $workspaceRoot "plc\instruction-plans\latest\instruction-route-table.md"
$safetyRiskPath = Join-Path $workspaceRoot "plc\instruction-plans\latest\safety-risk-assessment.md"
$winccBlueprintPath = Join-Path $workspaceRoot "wincc\component-blueprints\latest\component-blueprints.md"
$winccTaskPath = Join-Path $workspaceRoot "wincc\tasks\latest\engineering-tasks.json"
$latestWriteRun = Get-ChildItem -LiteralPath (Join-Path $workspaceRoot "runs") -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "write-cycle*" } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

$plcsimApi = Find-FirstExistingPath @(
    "C:\Program Files (x86)\Siemens\Automation\S7-PLCSIM Advanced\API\Siemens.Simatic.Simulation.Runtime.Api.x64.dll",
    "C:\Program Files\Siemens\Automation\S7-PLCSIM Advanced\API\Siemens.Simatic.Simulation.Runtime.Api.x64.dll",
    "C:\Program Files (x86)\Siemens\Automation\S7-PLCSIM Advanced\API\Siemens.Simatic.Simulation.Runtime.Api.dll",
    "C:\Program Files\Siemens\Automation\S7-PLCSIM Advanced\API\Siemens.Simatic.Simulation.Runtime.Api.dll"
)
$plcsimExe = Find-FirstExistingPath @(
    "C:\Program Files (x86)\Siemens\Automation\S7-PLCSIM Advanced\S7-PLCSIM Advanced.exe",
    "C:\Program Files\Siemens\Automation\S7-PLCSIM Advanced\S7-PLCSIM Advanced.exe"
)

$scenarios = New-Object System.Collections.ArrayList
Add-Scenario $scenarios "compile-clone" "克隆编译_CloneCompile" "导入生成块/源到克隆工程并执行 compile-plc 或 write-cycle" "编译无错误，报告保存，失败时记录块名、网络、源文件和诊断" "workflow-report.json, compile log, re-export summary" "避免把未验证 XML/SCL 写入主工程"
Add-Scenario $scenarios "manual-auto-mode" "手自动切换_ManualAuto" "模拟手动/自动/急停/暂停/复位/启动条件变化" "模式切换无误动作，命令掉电或复位优先级明确" "scenario log, tag trace table" "防止模式切换时机构误动作"
Add-Scenario $scenarios "interlock-fault" "互锁与故障_InterlockFault" "逐项断开门禁、气压、过载、通信、到位反馈和安全允许" "对应命令禁用、报警保持、HMI 显示互锁原因" "alarm/interlock coverage table" "防止互锁遗漏或故障被确认后自动清除"
Add-Scenario $scenarios "sequence-cycle" "顺控节拍_SequenceCycle" "给入站/出站/到位/超时信号，跑完整自动循环" "步号单调或按设计跳转，超时进入安全停机或报警分支" "step trace, timer snapshot" "防止步骤卡死、重复触发或越步"
Add-Scenario $scenarios "drive-comm" "驱动通信_DriveComm" "模拟 BUSY/DONE/ERROR/STATUS、速度设定和反馈延迟" "通信故障、陈旧数据和状态字诊断可见" "status word table, retry counter log" "防止通信丢失时继续使用旧数据"
Add-Scenario $scenarios "wincc-runtime-smoke" "WinCC运行冒烟_WinccRuntimeSmoke" "在可信 Unified Runtime 上只读订阅关键标签，必要时按用户授权写测试标签" "画面绑定、报警、趋势和诊断对象显示正确" "GraphQL read/subscribe capture" "运行时写入和报警确认必须显式授权"

$projectModelValue = ""
$agentContextValue = ""
$instructionPlanValue = ""
$safetyRiskValue = ""
$winccBlueprintValue = ""
$winccTaskValue = ""
$latestWriteValue = ""
if (Test-Path -LiteralPath $projectModelPath -PathType Leaf) { $projectModelValue = $projectModelPath }
if (Test-Path -LiteralPath $agentContextPath -PathType Leaf) { $agentContextValue = $agentContextPath }
if (Test-Path -LiteralPath $instructionPlanPath -PathType Leaf) { $instructionPlanValue = $instructionPlanPath }
if (Test-Path -LiteralPath $safetyRiskPath -PathType Leaf) { $safetyRiskValue = $safetyRiskPath }
if (Test-Path -LiteralPath $winccBlueprintPath -PathType Leaf) { $winccBlueprintValue = $winccBlueprintPath }
if (Test-Path -LiteralPath $winccTaskPath -PathType Leaf) { $winccTaskValue = $winccTaskPath }
if ($latestWriteRun) { $latestWriteValue = $latestWriteRun.FullName }

$package = [pscustomobject]@{
    schemaVersion = 1
    generatedAt = (Get-Date).ToString("o")
    projectRoot = $root
    workflowConfigPath = $WorkflowConfigPath
    taskText = $TaskText
    plcsimAdvanced = [pscustomobject]@{
        apiPath = $plcsimApi
        executablePath = $plcsimExe
        detected = (-not [string]::IsNullOrWhiteSpace($plcsimApi) -or -not [string]::IsNullOrWhiteSpace($plcsimExe))
        role = "virtual-controller and co-simulation target after clone compile"
    }
    runtimeValidation = [pscustomobject]@{
        default = "read-only smoke tests"
        winccUnifiedGraphql = "trusted endpoint only; read/subscribe by default; write/ack only with explicit user intent"
        productionDownloadAllowed = $false
    }
    inputs = [pscustomobject]@{
        projectModel = $projectModelValue
        agentContext = $agentContextValue
        instructionPlan = $instructionPlanValue
        safetyRisk = $safetyRiskValue
        winccComponentBlueprints = $winccBlueprintValue
        winccEngineeringTasks = $winccTaskValue
        latestWriteCycle = $latestWriteValue
    }
    scenarios = @($scenarios)
    releaseAllowed = $false
}

$jsonPath = Join-Path $OutputDirectory "simulation-package.json"
$latestJsonPath = Join-Path $latestDir "simulation-package.json"
$package | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
$package | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $latestJsonPath -Encoding UTF8

$scenarioCsvPath = Join-Path $OutputDirectory "simulation-scenarios.csv"
$latestScenarioCsvPath = Join-Path $latestDir "simulation-scenarios.csv"
@($scenarios) | Export-Csv -LiteralPath $scenarioCsvPath -NoTypeInformation -Encoding UTF8
@($scenarios) | Export-Csv -LiteralPath $latestScenarioCsvPath -NoTypeInformation -Encoding UTF8

$md = New-Object System.Text.StringBuilder
[void]$md.AppendLine("# Simulation And Runtime Validation Package")
[void]$md.AppendLine()
[void]$md.AppendLine("- Project: ``$root``")
[void]$md.AppendLine("- Task: $TaskText")
[void]$md.AppendLine("- PLCSIM Advanced API: ``$plcsimApi``")
[void]$md.AppendLine("- PLCSIM Advanced EXE: ``$plcsimExe``")
[void]$md.AppendLine("- Production download allowed: ``false``")
[void]$md.AppendLine("- Generated: ``$(Get-Date -Format o)``")
[void]$md.AppendLine()
[void]$md.AppendLine("## Validation Ladder")
[void]$md.AppendLine()
[void]$md.AppendLine("1. Static source/XML validation.")
[void]$md.AppendLine("2. Clone project import and compile through `write-cycle` or `compile-plc`.")
[void]$md.AppendLine("3. Re-export/readback and semantic diff.")
[void]$md.AppendLine("4. Optional PLCSIM Advanced virtual-controller smoke test.")
[void]$md.AppendLine("5. Optional WinCC Unified GraphQL read/subscribe smoke test on a trusted runtime.")
[void]$md.AppendLine("6. Review package and explicit production release gate.")
[void]$md.AppendLine()
[void]$md.AppendLine("## Scenario Matrix")
[void]$md.AppendLine()
foreach ($scenario in $scenarios) {
    [void]$md.AppendLine("### " + $scenario.name)
    [void]$md.AppendLine("- Stimulus: " + $scenario.stimulus)
    [void]$md.AppendLine("- Expected: " + $scenario.expected)
    [void]$md.AppendLine("- Evidence: " + $scenario.evidence)
    [void]$md.AppendLine("- Risk: " + $scenario.risk)
    [void]$md.AppendLine()
}
[void]$md.AppendLine("## Current Project Evidence")
[void]$md.AppendLine()
[void]$md.AppendLine("- Project model: ``$projectModelValue``")
[void]$md.AppendLine("- PLC instruction plan: ``$instructionPlanValue``")
[void]$md.AppendLine("- Safety risk: ``$safetyRiskValue``")
[void]$md.AppendLine("- WinCC component blueprints: ``$winccBlueprintValue``")
[void]$md.AppendLine("- Latest write-cycle: ``$latestWriteValue``")
[void]$md.AppendLine()
[void]$md.AppendLine("## Source Anchors")
[void]$md.AppendLine()
[void]$md.AppendLine("- Siemens S7-PLCSIM Advanced developer overview and API documentation.")
[void]$md.AppendLine("- Siemens TIA Portal Openness import/export and compile workflows.")
[void]$md.AppendLine("- Siemens WinCC Unified GraphQL runtime documentation for read/write/subscribe validation.")
[void]$md.AppendLine()
[void]$md.AppendLine("## Safety Notes")
[void]$md.AppendLine()
[void]$md.AppendLine((Read-ShortText -Path $safetyRiskPath -Max 2000))

$mdPath = Join-Path $OutputDirectory "simulation-package.md"
$latestMdPath = Join-Path $latestDir "simulation-package.md"
$md.ToString() | Set-Content -LiteralPath $mdPath -Encoding UTF8
$md.ToString() | Set-Content -LiteralPath $latestMdPath -Encoding UTF8

$plcsimNotes = @"
# PLCSIM Advanced Hook Notes

- Detect S7-PLCSIM Advanced before enabling virtual-controller execution.
- Compile and prepare a downloadable clone first; do not download or start runtime from the generator.
- Keep API calls explicit: create/start instance, load project, switch run/stop, drive input table, read outputs, archive evidence.
- Treat network simulation, safety CPU behavior, passwords and protected configuration as project-specific gates.
"@
$plcsimNotes | Set-Content -LiteralPath (Join-Path $OutputDirectory "plcsim-advanced-hook-notes.md") -Encoding UTF8
$plcsimNotes | Set-Content -LiteralPath (Join-Path $latestDir "plcsim-advanced-hook-notes.md") -Encoding UTF8

$winccSmoke = @"
# WinCC Runtime Smoke Notes

- Use WinCC Unified GraphQL only against a trusted configured endpoint.
- Default to query/subscription tests for tags, alarms and runtime state.
- Do not write tags, acknowledge alarms or trigger commands unless the user explicitly requests that trusted runtime action.
- Capture request scope, endpoint, user, timestamp, changed tags and rollback notes as evidence.
"@
$winccSmoke | Set-Content -LiteralPath (Join-Path $OutputDirectory "wincc-runtime-smoke-notes.md") -Encoding UTF8
$winccSmoke | Set-Content -LiteralPath (Join-Path $latestDir "wincc-runtime-smoke-notes.md") -Encoding UTF8

[pscustomobject]@{
    status = "ok"
    outputDirectory = $OutputDirectory
    latestDirectory = $latestDir
    simulationPackage = $mdPath
    simulationJson = $jsonPath
    scenarioCount = $scenarios.Count
    plcsimDetected = $package.plcsimAdvanced.detected
    releaseAllowed = $false
} | ConvertTo-Json -Depth 6
