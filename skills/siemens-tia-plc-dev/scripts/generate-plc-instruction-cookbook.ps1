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

function Add-Family {
    param(
        $Items,
        [string]$Id,
        [string]$Name,
        [string]$Instructions,
        [string]$PreferredSurface,
        [string]$TemplateRoute,
        [string]$RequiredContract,
        [string]$ValidationGate,
        [string]$RiskNote,
        [string]$ExampleAnchor
    )

    [void]$Items.Add([pscustomobject]@{
        id = $Id
        name = $Name
        instructions = $Instructions
        preferredSurface = $PreferredSurface
        templateRoute = $TemplateRoute
        requiredContract = $RequiredContract
        validationGate = $ValidationGate
        riskNote = $RiskNote
        exampleAnchor = $ExampleAnchor
    })
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

$root = Resolve-ProjectDirectory -Path $ProjectPath
$workspaceRoot = Join-Path $root "PLC_Code"
if ([string]::IsNullOrWhiteSpace($WorkflowConfigPath)) { $WorkflowConfigPath = Join-Path $workspaceRoot "config\ai-workflow.json" }
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $workspaceRoot ("plc\instruction-cookbook\" + (Get-Date -Format "yyyyMMdd-HHmmss"))
}
$latestDir = Join-Path $workspaceRoot "plc\instruction-cookbook\latest"
New-Item -ItemType Directory -Path $OutputDirectory, $latestDir -Force | Out-Null

$skillRoot = Split-Path -Parent $PSScriptRoot
$ladExampleRoot = Join-Path $skillRoot "examples\classic-lad"
$sclExampleRoot = Join-Path $skillRoot "examples\classic-scl"
$routePath = Join-Path $workspaceRoot "plc\instruction-plans\latest\instruction-route-table.md"
$knowledgePath = Join-Path $workspaceRoot "knowledge\packs\latest\knowledge-brief.md"
$projectModelPath = Join-Path $workspaceRoot "workbench\context\latest\project-model.json"
$latestRouteTable = ""
$latestKnowledgeBrief = ""
$latestProjectModel = ""
if (Test-Path -LiteralPath $routePath -PathType Leaf) { $latestRouteTable = $routePath }
if (Test-Path -LiteralPath $knowledgePath -PathType Leaf) { $latestKnowledgeBrief = $knowledgePath }
if (Test-Path -LiteralPath $projectModelPath -PathType Leaf) { $latestProjectModel = $projectModelPath }

$families = New-Object System.Collections.ArrayList
Add-Family $families "bit-logic" "位逻辑与线圈_BitLogic" "NO, NC, P_EDGE, N_EDGE, COIL, SET, RESET" "LAD JSON" "write-lad-network / write-lad-batch" "命令_Cmd、反馈_Fb、互锁_Intlk、报警_Alm 分离" "validate-lad -> clone import -> compile -> re-export summary" "防止自保持无法复位、命令反馈混用、互锁遗漏" "examples/classic-lad/start-stop-single-coil"
Add-Family $families "compare-timer-counter" "比较定时计数_CompareTimerCounter" "EQ, NE, GE, GT, LE, LT, TON, TOF, TP, CTU, CTD, CTUD" "LAD JSON" "LAD JSON timer/counter actions plus supporting-sources for new IEC instances" "定时器实例_Timer、计数器实例_Counter、预设值_Preset、复位_Reset" "inspect-lad -> validate-lad -> clone compile; check missing instance DB hints" "防止 PT 类型错误、计数沿重复、复位优先级不清" "examples/classic-lad/sequence-branch-ton-batch"
Add-Family $families "data-move-select" "数据移动与选择_MoveSelect" "MOVE, SEL, MUX, simple setpoint transfer" "LAD JSON for simple MOVE; SCL for wider selection" "MOVE action with signalSource/signalTarget, or SCL source import" "源值_Source、目标值_Target、使能_Enable、范围_Limits" "clone compile plus boundary-value table" "防止类型隐式转换、ENO 链误用、参数写入无权限" "examples/classic-lad/dual-move-eno-chain"
Add-Family $families "math-scale" "运算缩放_MathScale" "ADD, SUB, MUL, DIV, NORM_X, SCALE_X, LIMIT, ABS, MIN, MAX, ROUND, TRUNC" "SCL source import" "SCL FC/FB with LAD-visible permissive/alarm layer" "原始值_Raw、工程值_Engineering、单位_Unit、上下限_Limits、断线_BrokenWire" "source import -> clone compile -> boundary/min/max/out-of-range review" "防止量程、单位、小数精度、除零和断线处理遗漏" "examples/classic-scl/analog-scaling-fc"
Add-Family $families "word-pack-convert" "字逻辑与转换_WordConvert" "AND, OR, XOR, NOT, SHL, SHR, ROL, ROR, type conversions, status-word build/decode" "SCL source import; donor LAD for exact boxes" "SCL helper plus HMI diagnostic DB contract" "状态字_StatusWord、掩码_Mask、位定义_BitMap、字节序_Endian" "compile plus bit-table review and HMI diagnostic readback" "防止字节序、掩码、移位宽度和符号类型错误" "examples/classic-scl/status-word-builder-fc"
Add-Family $families "array-string-recipe" "数组字符串配方_ArrayStringRecipe" "ARRAY operations, string formatting, recipe copy, buffer handling, MOVE_BLK_VARIANT" "SCL source import" "SCL FB/FC plus DB contract and HMI write authority" "配方_Recipe、缓冲_Buffer、索引_Index、长度_Length、写入命令_WriteCmd" "source import -> compile -> index/range table review" "防止越界、长度不一致、配方写入无确认" "examples/classic-scl/material-handling-cell"
Add-Family $families "motion-to" "运动与工艺对象_MotionTO" "MC_Power, MC_Reset, MC_Home, MC_MoveAbsolute, MC_MoveRelative, MC_MoveVelocity, MC_Halt, MC_Stop, MC_MoveJog" "Generic CALL + technology object contract" "typed CALL networks; technology-object-plan; vendor axis DB" "轴_Axis、使能_Enable、回零_Home、点动_Jog、目标_Target、状态_Status、错误_Error" "CPU/firmware/TO name check -> clone compile -> authority/risk review" "高风险：运动授权、极限、停止、复位、回零和安全停止必须工程确认" "examples/classic-lad/motion-axis-core-batch"
Add-Family $families "drive-comm" "驱动通信_DriveCommunication" "MB_COMM_LOAD, MB_MASTER, MB_CLIENT, MB_SERVER, TCP/serial/vendor drive blocks" "Generic CALL + parameter DB + SCL parser" "CALL networks for REQ/BUSY/DONE/ERROR/STATUS; SCL for data decode" "连接_Connection、请求_Req、忙碌_Busy、完成_Done、错误_Error、状态_Status、重试_Retry" "clone compile -> stale-data simulation note -> HMI diagnostics" "防止重复 REQ、地址长度错误、通信故障不报警、陈旧数据继续使用" "examples/classic-lad/mb-master-readfreq"
Add-Family $families "pid-process" "PID与过程控制_PIDProcess" "PID_Compact, PID_3Step, setpoint limits, manual/auto transfer" "Library CALL + parameter DB + HMI trend/authority" "CALL network or vendor/library FB with parameter DB contract" "设定_Setpoint、反馈_ProcessValue、输出_Output、手自动_ManualAuto、限幅_Limit" "compile -> parameter range review -> trend/HMI contract" "高风险：模式切换、输出限幅、参数写入权限和无扰切换必须审查" "examples/classic-scl/analog-scaling-fc"
Add-Family $families "diagnostic-system" "诊断系统_DiagnosticSystem" "system diagnostics, module status, clock/time, runtime counters, alarm aggregation" "Generic CALL or SCL source import" "SCL aggregator plus LAD/HMI alarm/status surface" "诊断_Diagnostics、时间_Time、模块_Module、报警_Alarm、首出_FirstOut" "compile -> HMI visibility review -> fault injection note" "防止隐藏故障、时间戳不一致、报警复位语义错误" "examples/classic-scl/station-supervisor-fb"

$ladExamples = @()
if (Test-Path -LiteralPath $ladExampleRoot -PathType Container) {
    $ladExamples = Get-ChildItem -LiteralPath $ladExampleRoot -File -ErrorAction SilentlyContinue |
        Sort-Object Name |
        Select-Object -ExpandProperty Name
}
$sclExamples = @()
if (Test-Path -LiteralPath $sclExampleRoot -PathType Container) {
    $sclExamples = Get-ChildItem -LiteralPath $sclExampleRoot -Recurse -File -ErrorAction SilentlyContinue |
        Sort-Object FullName |
        Select-Object -First 80 |
        ForEach-Object { $_.FullName.Substring($sclExampleRoot.Length).TrimStart('\') }
}

$json = [pscustomobject]@{
    schemaVersion = 1
    generatedAt = (Get-Date).ToString("o")
    projectRoot = $root
    workflowConfigPath = $WorkflowConfigPath
    taskText = $TaskText
    namingRule = "中文_English"
    sourcePriority = @("Siemens official instruction docs", "current project exports", "verified local examples", "reviewed community source")
    families = @($families)
    availableExamples = [pscustomobject]@{
        lad = @($ladExamples)
        scl = @($sclExamples)
    }
    context = [pscustomobject]@{
        latestRouteTable = $latestRouteTable
        latestKnowledgeBrief = $latestKnowledgeBrief
        projectModel = $latestProjectModel
    }
    releaseAllowed = $false
}

$jsonPath = Join-Path $OutputDirectory "instruction-cookbook.json"
$latestJsonPath = Join-Path $latestDir "instruction-cookbook.json"
$json | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
$json | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $latestJsonPath -Encoding UTF8

$md = New-Object System.Text.StringBuilder
[void]$md.AppendLine("# PLC Instruction Cookbook")
[void]$md.AppendLine()
[void]$md.AppendLine("- Project: ``$root``")
[void]$md.AppendLine("- Task: $TaskText")
[void]$md.AppendLine("- Naming: ``中文_English``")
[void]$md.AppendLine("- Generated: ``$(Get-Date -Format o)``")
[void]$md.AppendLine()
[void]$md.AppendLine("## How To Use")
[void]$md.AppendLine()
[void]$md.AppendLine("- Start from this cookbook before generating advanced PLC code.")
[void]$md.AppendLine("- Keep operator-facing interlocks, alarms, mode logic, timers, counters and simple sequence transitions in LAD where practical.")
[void]$md.AppendLine("- Use generic named-pin CALL networks for motion, communication, drives, PID and library FBs.")
[void]$md.AppendLine("- Use SCL for math, scaling, conversion, strings, arrays, recipes and protocol parsing.")
[void]$md.AppendLine("- Validate through clone import/compile/readback before any production release.")
[void]$md.AppendLine()
[void]$md.AppendLine("## Instruction Families")
[void]$md.AppendLine()
[void]$md.AppendLine("| Family | Instructions | Preferred Surface | Template Route | Required Contract | Validation | Risk |")
[void]$md.AppendLine("| --- | --- | --- | --- | --- | --- | --- |")
foreach ($family in $families) {
    [void]$md.AppendLine("| $($family.name) | $($family.instructions) | $($family.preferredSurface) | $($family.templateRoute) | $($family.requiredContract) | $($family.validationGate) | $($family.riskNote) |")
}
[void]$md.AppendLine()
[void]$md.AppendLine("## LAD JSON Pattern Seeds")
[void]$md.AppendLine()
[void]$md.AppendLine("Use these as shape names for code generation rather than copying unknown XML blindly:")
[void]$md.AppendLine()
[void]$md.AppendLine("- ``series_contacts_to_coil``: NO/NC chain to COIL, SET or RESET.")
[void]$md.AppendLine("- ``compare_timer_alarm``: compare condition starts TON/TOF/TP, timer.Q sets alarm or step.")
[void]$md.AppendLine("- ``edge_counter_reset``: P_EDGE/N_EDGE counts through CTU/CTD/CTUD with separate reset/load path.")
[void]$md.AppendLine("- ``typed_call_with_status``: CALL with named inputs/outputs, BUSY/DONE/ERROR/STATUS mapped to diagnostics.")
[void]$md.AppendLine("- ``move_chain``: MOVE with EN/ENO chain and explicit target contract.")
[void]$md.AppendLine("- ``shared_prefix_branches``: common permissive fan-out to several commands or step transitions.")
[void]$md.AppendLine()
[void]$md.AppendLine("## Existing Example Anchors")
[void]$md.AppendLine()
foreach ($family in $families) {
    [void]$md.AppendLine("- $($family.name): ``$($family.exampleAnchor)``")
}
[void]$md.AppendLine()
[void]$md.AppendLine("## Current Context Excerpts")
[void]$md.AppendLine()
[void]$md.AppendLine("### Knowledge Brief")
[void]$md.AppendLine()
[void]$md.AppendLine('```text')
[void]$md.AppendLine((Read-ShortText -Path $knowledgePath -Max 2200))
[void]$md.AppendLine('```')
[void]$md.AppendLine()
[void]$md.AppendLine("### Instruction Route")
[void]$md.AppendLine()
[void]$md.AppendLine('```text')
[void]$md.AppendLine((Read-ShortText -Path $routePath -Max 2200))
[void]$md.AppendLine('```')

$mdPath = Join-Path $OutputDirectory "instruction-cookbook.md"
$latestMdPath = Join-Path $latestDir "instruction-cookbook.md"
$md.ToString() | Set-Content -LiteralPath $mdPath -Encoding UTF8
$md.ToString() | Set-Content -LiteralPath $latestMdPath -Encoding UTF8

$riskChecklist = @"
# PLC Instruction Risk Checklist

- Commands, feedback, status, interlocks, alarms, parameters and diagnostics use separate tags.
- Every HMI command has a nearby feedback and disabled/interlock reason.
- Motion, reset, homing, jog, recipe write and parameter write require authority and confirmation where appropriate.
- Timers and counters have explicit instance strategy and reset priority.
- Communication blocks expose BUSY, DONE, ERROR, STATUS, retry count and stale-data alarm.
- Analog and numeric logic includes units, scaling limits, broken-wire or invalid-value handling.
- String, array and recipe logic includes bounds and length checks.
- Safety-rated behavior is not generated as an ordinary PLC convenience feature.
"@
$riskChecklist | Set-Content -LiteralPath (Join-Path $OutputDirectory "instruction-risk-checklist.md") -Encoding UTF8
$riskChecklist | Set-Content -LiteralPath (Join-Path $latestDir "instruction-risk-checklist.md") -Encoding UTF8

[pscustomobject]@{
    status = "ok"
    outputDirectory = $OutputDirectory
    latestDirectory = $latestDir
    cookbook = $mdPath
    cookbookJson = $jsonPath
    familyCount = $families.Count
    releaseAllowed = $false
} | ConvertTo-Json -Depth 6

