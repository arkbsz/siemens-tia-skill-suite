param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    [string]$WorkflowConfigPath = "",

    [string]$TaskText = "",

    [string]$SourceXml = "",

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

function Test-Any {
    param([string]$Text, [string[]]$Needles)
    foreach ($needle in $Needles) {
        if ($Text.IndexOf($needle, [StringComparison]::OrdinalIgnoreCase) -ge 0) { return $true }
    }
    return $false
}

function Add-Route {
    param(
        [System.Collections.Generic.List[object]]$Routes,
        [string]$Family,
        [string]$Examples,
        [string]$Surface,
        [string]$Why,
        [string]$Gate,
        [string]$Risk
    )
    [void]$Routes.Add([pscustomobject]@{
        family = $Family
        examples = $Examples
        preferredSurface = $Surface
        reason = $Why
        verificationGate = $Gate
        risk = $Risk
    })
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

$root = Resolve-ProjectDirectory -Path $ProjectPath
$workspaceRoot = Join-Path $root "PLC_Code"
if ([string]::IsNullOrWhiteSpace($WorkflowConfigPath)) { $WorkflowConfigPath = Join-Path $workspaceRoot "config\ai-workflow.json" }
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $workspaceRoot ("plc\instruction-plans\" + (Get-Date -Format "yyyyMMdd-HHmmss"))
}
$latestDir = Join-Path $workspaceRoot "plc\instruction-plans\latest"
New-Item -ItemType Directory -Path $OutputDirectory, $latestDir -Force | Out-Null

$text = "$TaskText $SourceXml"
$routes = New-Object System.Collections.Generic.List[object]

if (Test-Any -Text $text -Needles @("lad", "梯形图", "互锁", "联锁", "启动", "停止", "报警", "计时", "计数", "步序", "顺控")) {
    Add-Route $routes "维护可读 LAD 控制层" "NO/NC/P_EDGE/N_EDGE/EQ/GE/TON/TOF/TP/CTU/CTD/CTUD/COIL/SET/RESET/MOVE" "LAD JSON -> XML, or donor LAD network patch" "操作、联锁、报警和顺控状态需要维护人员直接读懂。" "inspect-lad, summarize-lad, validate-lad, clone compile" "低到中；重点防止互锁遗漏和命令反馈混用。"
}
if (Test-Any -Text $text -Needles @("motion", "轴", "伺服", "回原点", "回零", "定位", "MC_", "MC_Power", "MC_Move", "technology", "工艺对象")) {
    Add-Route $routes "运动控制与工艺对象" "MC_Power/MC_Reset/MC_Home/MC_MoveAbsolute/MC_MoveRelative/MC_MoveVelocity/MC_Halt/MC_Stop" "Technology object contract + generic CALL networks" "运动指令是带实例和轴对象的 typed call，不应伪造成普通位逻辑。" "CPU/firmware/TO name check, clone compile, motion authority risk review" "高；必须明确使能、停止、复位、回原点、点动、极限和安全停止假设。"
}
if (Test-Any -Text $text -Needles @("modbus", "tcp", "通信", "通讯", "mb_", "MB_MASTER", "MB_CLIENT", "MB_SERVER", "变频器", "drive")) {
    Add-Route $routes "通信与驱动" "MB_COMM_LOAD/MB_MASTER/MB_CLIENT/MB_SERVER/vendor drive FBs" "Generic CALL + parameter DB + SCL parsing helpers" "连接建立、请求循环、BUSY/DONE/ERROR/STATUS 和数据解析应分层表达。" "clone compile, status-word exposure, retry/stale-data simulation note" "中到高；防止重复 REQ、错误地址长度、陈旧数据和未显示通信故障。"
}
if (Test-Any -Text $text -Needles @("pid", "PID", "工艺控制", "温控", "压力", "流量", "闭环")) {
    Add-Route $routes "PID 与工艺控制" "PID_Compact, PID_3Step, limits, manual/auto transfer" "Library/technology CALL + parameter DB + HMI trend/parameter contract" "PID 参数、手自动切换和限幅需要工程参数与操作画面配合。" "clone compile, parameter range review, manual/auto bumpless transfer note" "高；参数写入、模式切换和输出限幅必须受权限和安全策略约束。"
}
if (Test-Any -Text $text -Needles @("模拟量", "analog", "scale", "NORM_X", "SCALE_X", "LIMIT", "滤波", "单位", "工程量")) {
    Add-Route $routes "模拟量缩放与限幅" "NORM_X/SCALE_X/LIMIT/ABS/MIN/MAX/ROUND/TRUNC/filter" "SCL source import, with LAD-visible alarm/permissive layer" "算法和单位转换在 SCL 中更清晰，报警和允许条件再暴露给 LAD/HMI。" "source import, clone compile, boundary-value table" "中；重点检查量程、单位、断线、上下限和 HMI 显示一致性。"
}
if (Test-Any -Text $text -Needles @("字符串", "string", "数组", "array", "配方", "recipe", "缓冲", "buffer", "报文", "字节", "word", "状态字")) {
    Add-Route $routes "数据处理、数组、字符串与状态字" "SEL/SHL/SHR/AND/OR/XOR/conversion/string/array/copy/pack" "SCL source import, plus HMI/diagnostic DB contract" "复杂数据处理用 SCL 更可审查，避免生成难维护的大型 LAD box 网络。" "unit-style test table, source import, clone compile" "中；重点检查下标、字节序、掩码、类型转换和越界。"
}
if ($routes.Count -eq 0) {
    Add-Route $routes "通用 PLC 开发" "contacts, timers, counters, DB contracts, SCL helpers, generic CALL" "Classify first: LAD JSON, SCL source, generic CALL or donor network" "任务未命中特定指令族，先建立变量契约和最小可验证改动。" "read-cycle, generated package review, clone compile" "待评估；先输出安全假设和验证清单。"
}

$sourceExcerpt = Read-ShortText -Path $SourceXml -Max 6000
$blockCatalog = ""
$runsRoot = Join-Path $workspaceRoot "runs"
if (Test-Path -LiteralPath $runsRoot -PathType Container) {
    $catalogPath = Get-ChildItem -LiteralPath $runsRoot -Directory -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        ForEach-Object { Join-Path $_.FullName "reports\block-list.txt" } |
        Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
        Select-Object -First 1
    $blockCatalog = Read-ShortText -Path $catalogPath -Max 6000
}

$routeJson = [pscustomobject]@{
    schemaVersion = 1
    generatedAt = (Get-Date).ToString("o")
    projectRoot = $root
    workflowConfigPath = $WorkflowConfigPath
    taskText = $TaskText
    sourceXml = $(if (-not [string]::IsNullOrWhiteSpace($SourceXml) -and (Test-Path -LiteralPath $SourceXml -PathType Leaf)) { (Get-Item -LiteralPath $SourceXml).FullName } else { "" })
    routes = @($routes.ToArray())
    namingRule = "中文_English"
    releaseAllowed = $false
}
$routeJsonPath = Join-Path $OutputDirectory "instruction-route-table.json"
$latestRouteJsonPath = Join-Path $latestDir "instruction-route-table.json"
$routeJson | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $routeJsonPath -Encoding UTF8
$routeJson | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $latestRouteJsonPath -Encoding UTF8

$routeMd = New-Object System.Text.StringBuilder
[void]$routeMd.AppendLine("# PLC Instruction Route Table")
[void]$routeMd.AppendLine()
[void]$routeMd.AppendLine("- Project: ``$root``")
[void]$routeMd.AppendLine("- Task: $TaskText")
$sourceXmlDisplay = if (-not [string]::IsNullOrWhiteSpace($SourceXml) -and (Test-Path -LiteralPath $SourceXml -PathType Leaf)) { (Get-Item -LiteralPath $SourceXml).FullName } else { "none" }
[void]$routeMd.AppendLine("- Source XML: ``$sourceXmlDisplay``")
[void]$routeMd.AppendLine("- Naming: ``中文_English``")
[void]$routeMd.AppendLine("- Release allowed: ``false``")
[void]$routeMd.AppendLine()
[void]$routeMd.AppendLine("## Routes")
[void]$routeMd.AppendLine()
foreach ($route in $routes) {
    [void]$routeMd.AppendLine("### " + $route.family)
    [void]$routeMd.AppendLine("- Examples: " + $route.examples)
    [void]$routeMd.AppendLine("- Preferred surface: " + $route.preferredSurface)
    [void]$routeMd.AppendLine("- Reason: " + $route.reason)
    [void]$routeMd.AppendLine("- Verification gate: " + $route.verificationGate)
    [void]$routeMd.AppendLine("- Risk: " + $route.risk)
    [void]$routeMd.AppendLine()
}
[void]$routeMd.AppendLine("## Current Project Context")
[void]$routeMd.AppendLine()
[void]$routeMd.AppendLine('```text')
[void]$routeMd.AppendLine($blockCatalog)
[void]$routeMd.AppendLine('```')
[void]$routeMd.AppendLine()
[void]$routeMd.AppendLine("## Source Excerpt")
[void]$routeMd.AppendLine()
[void]$routeMd.AppendLine('```xml')
[void]$routeMd.AppendLine($sourceExcerpt)
[void]$routeMd.AppendLine('```')
$routeMdPath = Join-Path $OutputDirectory "instruction-route-table.md"
$latestRouteMdPath = Join-Path $latestDir "instruction-route-table.md"
$routeMd.ToString() | Set-Content -LiteralPath $routeMdPath -Encoding UTF8
$routeMd.ToString() | Set-Content -LiteralPath $latestRouteMdPath -Encoding UTF8

$toPlan = @"
# Technology Object Plan

Use this file when the route table includes motion, drive, PID, or other technology/library objects.

Required checks:
- CPU family, firmware, TIA version and licensed options.
- Technology object name, generated DBs, axis/drive interface and update cycle.
- Commands: 使能命令_EnableCmd, 复位命令_ResetCmd, 回原点命令_HomeCmd, 点动正向_JogPositiveCmd, 点动反向_JogNegativeCmd, 停止命令_StopCmd.
- Feedback: 已使能_PoweredFb, 已回原点_HomedFb, 忙碌状态_BusySts, 完成状态_DoneSts, 错误状态_ErrorSts, 错误代码_ErrorId.
- HMI authority and confirmation for reset, homing, jog, move and parameter writes.
- Simulation or dry-run strategy before any production download.
"@
$toPlan | Set-Content -LiteralPath (Join-Path $OutputDirectory "technology-object-plan.md") -Encoding UTF8
$toPlan | Set-Content -LiteralPath (Join-Path $latestDir "technology-object-plan.md") -Encoding UTF8

$riskMd = @"
# PLC Safety Risk Assessment

Generated: $(Get-Date -Format o)

Risk triggers detected from this task:

$(($routes | ForEach-Object { "- " + $_.family + ": " + $_.risk }) -join [Environment]::NewLine)

Minimum review:
- Commands and feedback are separate tags.
- Manual/auto transfer is explicit and visible.
- Motion, reset, homing, recipe writes and communication writes require authority and confirmation where appropriate.
- Interlock failures are surfaced to HMI with readable disabled reasons.
- Alarm acknowledge/reset is not treated as fault removal unless the PLC logic confirms safe state.
- Safety-rated behavior is not invented by AI; it must stay inside the approved safety engineering workflow.
"@
$riskMd | Set-Content -LiteralPath (Join-Path $OutputDirectory "safety-risk-assessment.md") -Encoding UTF8
$riskMd | Set-Content -LiteralPath (Join-Path $latestDir "safety-risk-assessment.md") -Encoding UTF8

$readme = @"
# PLC Instruction Plan

Generated: $(Get-Date -Format s)
Project: `$root`
Output: `$OutputDirectory`

Files:
- instruction-route-table.md
- instruction-route-table.json
- technology-object-plan.md
- safety-risk-assessment.md

Use this package before editing blocks that involve advanced Siemens instructions, technology objects, communication, drives, PID, recipes, strings, arrays or safety-sensitive operator commands.
"@
$readme | Set-Content -LiteralPath (Join-Path $OutputDirectory "README.md") -Encoding UTF8
$readme | Set-Content -LiteralPath (Join-Path $latestDir "README.md") -Encoding UTF8

[pscustomobject]@{
    status = "ok"
    outputDirectory = $OutputDirectory
    latestDirectory = $latestDir
    routeTable = $routeMdPath
    routeJson = $routeJsonPath
    risk = Join-Path $OutputDirectory "safety-risk-assessment.md"
} | ConvertTo-Json -Depth 6
