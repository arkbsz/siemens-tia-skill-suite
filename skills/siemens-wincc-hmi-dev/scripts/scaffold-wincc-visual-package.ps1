param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    [string]$WorkflowConfigPath = "",
    [string]$TaskText = "",
    [string]$ReferenceImagePath = "",
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

function Write-Doc {
    param([string]$Path, [string]$Content)
    Set-Content -LiteralPath $Path -Value $Content -Encoding UTF8
}

$root = Resolve-ProjectDirectory -Path $ProjectPath
$workspaceRoot = Join-Path $root "PLC_Code"
if ([string]::IsNullOrWhiteSpace($WorkflowConfigPath)) { $WorkflowConfigPath = Join-Path $workspaceRoot "config\ai-workflow.json" }
$config = $null
if (Test-Path -LiteralPath $WorkflowConfigPath) { $config = Get-Content -LiteralPath $WorkflowConfigPath -Raw | ConvertFrom-Json }

if ([string]::IsNullOrWhiteSpace($ReferenceImagePath)) {
    $ReferenceImagePath = Get-ConfigValue -Config $config -Path @("image", "referenceImage") -Fallback ""
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $workspaceRoot "wincc\tasks\$stamp-visual-package"
}
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$latestDir = Join-Path $workspaceRoot "wincc\tasks\latest"
New-Item -ItemType Directory -Path $latestDir -Force | Out-Null

$winccFlavor = Get-ConfigValue -Config $config -Path @("wincc", "flavor") -Fallback "auto"
$pluginPolicy = Get-ConfigValue -Config $config -Path @("wincc", "pluginPolicy") -Fallback "auto"
$imageWorkflow = Get-ConfigValue -Config $config -Path @("image", "workflow") -Fallback "auto"
$imageModel = Get-ConfigValue -Config $config -Path @("image", "model") -Fallback "imagegen"
$componentStrategy = Get-ConfigValue -Config $config -Path @("image", "componentStrategy") -Fallback "auto"
$hasReferenceImage = -not [string]::IsNullOrWhiteSpace($ReferenceImagePath) -and (Test-Path -LiteralPath $ReferenceImagePath)
$pluginRoutingPath = Join-Path $workspaceRoot "wincc\plugin-routing.json"
$agentPlanPath = Join-Path $workspaceRoot "agent-plans\latest-plan.md"

$pluginRoutingText = ""
$pluginResolver = Join-Path $PSScriptRoot "resolve-wincc-plugins.ps1"
if (Test-Path -LiteralPath $pluginResolver) {
    try {
        $resolverArgs = @("-ProjectPath", $root, "-WorkflowConfigPath", $WorkflowConfigPath, "-TaskText", $TaskText)
        if ($hasReferenceImage) {
            $resolverArgs += @("-ReferenceImagePath", (Get-Item -LiteralPath $ReferenceImagePath).FullName)
        }
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $pluginResolver @resolverArgs | Out-Null
    }
    catch {
        $pluginRoutingText = "Plugin resolver failed: " + $_.Exception.Message
    }
}
if (Test-Path -LiteralPath $pluginRoutingPath) {
    $pluginRoutingText = Get-Content -LiteralPath $pluginRoutingPath -Raw -ErrorAction SilentlyContinue
}

$designBrief = @"
# WinCC Design Brief

Project: `$root`
Task: $TaskText
WinCC flavor: `$winccFlavor`
Plugin policy: `$pluginPolicy`
Image workflow: `$imageWorkflow`
Image model: `$imageModel`
Reference image: `$(if ($hasReferenceImage) { (Get-Item -LiteralPath $ReferenceImagePath).FullName } else { "none" })`
Component strategy: `$componentStrategy`

Goal:
Create editable WinCC engineering content, not a static screenshot. Match the requested operator workflow, PLC tag contract, safety state visibility and reference visual style.

Source priority:
Siemens official WinCC/TIA documents, official Openness snippets, reviewed community tools, current project exports, current DB/UDT/HMI contracts.
"@

$referenceAnalysis = @"
# Reference Analysis

Input:
- Reference image available: `$hasReferenceImage`
- Reference image path: `$(if ($hasReferenceImage) { (Get-Item -LiteralPath $ReferenceImagePath).FullName } else { "none" })`
- Text brief: $TaskText

If an image is available, analyze:
- layout zones: header, navigation, status strip, process area, side panels and footer.
- visual hierarchy: primary operator scan path, alarm salience, command grouping and dense areas.
- palette: background gradient, normal/running/warning/fault/disabled colors.
- typography: Chinese/English label length, numeric value size, units and readability.
- components: cards, pumps, motors, cylinders, valves, trends, alarms, parameter tables and dialogs.

If only text is available:
- generate a reference mockup first through the configured image workflow.
- use the mockup as a design target, then rebuild it with editable WinCC objects.
"@

$screenMap = @"
# Screen Map

- Overview_总览: machine state, mode, PLC connection, active alarm, current step, station status.
- Manual_手动: station-by-station jog/manual commands with feedback, interlock reason and command authority.
- Automatic_自动: sequence state, step transition conditions, pause/resume/reset confirmation and cycle counters.
- Alarms_报警: active alarms, first-out notes, acknowledge/reset rules and linked diagnostics.
- Trends_趋势: key analogs, cycle time, drive speed, pressure/position/current and alarm overlays.
- Parameters_参数: recipe and engineering parameters with min/max, unit, authority and change audit.
- Maintenance_维护: I/O forcing notes, diagnostics, actuator tests and safe maintenance mode.
- Diagnostics_诊断: PLC/HMI connection, communication status, drive status words and block health.
"@

$componentMap = @"
# Component Map

Selection order:
1. Existing project faceplates aligned with PLC DB/UDT.
2. Standard WinCC controls for buttons, lamps, I/O fields, trends, alarm views and navigation.
3. SiVArc rules for repeated stations/devices.
4. Custom faceplates for reusable machine cards.
5. CWC only when native controls cannot express the required widget.

Required components:
- Header_Header: machine name, mode, user level, PLC connection, time.
- AlarmStrip_报警条: active fault, warning, first-out hint, acknowledge state.
- StationCard_工位卡: state, command, feedback, interlock, fault, local/manual note.
- MotorFaceplate_电机面板: start/stop, direction, run feedback, overload, interlock.
- CylinderFaceplate_气缸面板: extend/retract commands, end sensors, timeout, air pressure.
- DriveFaceplate_变频器面板: enable, setpoint, actual speed, status word, fault code.
- TrendPanel_趋势面板: selected process values with units and limits.
- ParameterPanel_参数面板: DB-backed parameters with authority and confirmation.
"@

$componentSelection = @"
# Component Selection Matrix

| Zone | Preferred WinCC Object | Fallback | Data Contract | Notes |
| --- | --- | --- | --- | --- |
| Header_Header | Text, IOField, user/login display | custom faceplate | DB_系统_System | stable across screens |
| AlarmStrip_报警条 | AlarmView / alarm indicator | faceplate | DB_报警_Alarms | always visible on operation screens |
| StationCard_工位卡 | faceplate | SiVArc repeated object | UDT_工位_Station | one card per station/device |
| MotorFaceplate_电机 | faceplate with buttons/lamps | standard controls | UDT_电机_Motor | command and feedback tags separate |
| CylinderFaceplate_气缸 | faceplate | standard controls | UDT_气缸_Cylinder | extend/retract mutual exclusion |
| DriveFaceplate_变频器 | faceplate + trend | CWC for advanced chart | UDT_驱动_Drive | expose status word and fault code |
| TrendPanel_趋势 | TrendView | CWC chart | DB_趋势_Trend | use native trend first |
| ParameterPanel_参数 | IOField/table | CWC table | DB_参数_Parameters | authority and range checks required |
| Diagnostics_诊断 | Text lists, IOFields | CWC tree/table | DB_诊断_Diagnostics | useful for communication and module health |
| Navigation_导航 | screen buttons | generated menu faceplate | HMI internal tags | consistent on all screens |
"@

$tagContract = @"
# PLC-HMI Tag Contract

Naming format: Chinese_English, concise and readable.

Layers:
- Cmd: command tags, for example 启动命令_StartCmd.
- Fb: feedback tags, for example 运行反馈_RunFb.
- Sts: state tags, for example 自动状态_AutoSts.
- Intlk: interlock tags, for example 互锁允许_InterlockOk.
- Alm: alarm tags, for example 超时报警_TimeoutAlm.
- Par: parameter tags, for example 超时时间_TimeoutTime.
- Diag: diagnostic tags, for example 状态字_StatusWord.

Rules:
- A command tag must not be reused as feedback.
- Every command button needs nearby feedback and disabled/interlock reason.
- Reset, homing, recipe write and force-like actions require authority or confirmation.
"@

$componentCandidates = @"
{
  "schemaVersion": 1,
  "selectionOrder": [
    "existing-faceplate",
    "standard-wincc-control",
    "sivarc-rule",
    "custom-faceplate",
    "custom-web-control"
  ],
  "namingRule": "Chinese_English",
  "candidates": [
    {
      "id": "FP_电机_Motor",
      "kind": "faceplate",
      "priority": 1,
      "bindings": ["启动命令_StartCmd", "停止命令_StopCmd", "运行反馈_RunFb", "故障报警_FaultAlm", "互锁允许_InterlockOk"],
      "risk": "command-authority"
    },
    {
      "id": "FP_气缸_Cylinder",
      "kind": "faceplate",
      "priority": 1,
      "bindings": ["伸出命令_ExtendCmd", "缩回命令_RetractCmd", "伸出到位_ExtendFb", "缩回到位_RetractFb", "超时报警_TimeoutAlm"],
      "risk": "mutual-exclusion"
    },
    {
      "id": "FP_变频器_Drive",
      "kind": "faceplate",
      "priority": 1,
      "bindings": ["使能命令_EnableCmd", "速度设定_SpeedSp", "速度反馈_SpeedFb", "状态字_StatusWord", "故障代码_FaultCode"],
      "risk": "parameter-write"
    },
    {
      "id": "AlarmView_报警视图",
      "kind": "standard-wincc-control",
      "priority": 1,
      "bindings": ["当前报警_ActiveAlarm", "确认命令_AckCmd", "首出故障_FirstOutFault"],
      "risk": "acknowledge-confirmation"
    },
    {
      "id": "TrendView_趋势视图",
      "kind": "standard-wincc-control",
      "priority": 2,
      "bindings": ["过程值_ProcessValue", "设定值_Setpoint", "上限_HighLimit", "下限_LowLimit"],
      "risk": "read-only-preferred"
    },
    {
      "id": "CWC_诊断表_DiagnosticTable",
      "kind": "custom-web-control",
      "priority": 4,
      "bindings": ["诊断列表_DiagnosticList", "状态字_StatusWord", "通信状态_CommSts"],
      "risk": "review-source-before-import"
    }
  ]
}
"@

$styleGuide = @"
# Style Guide

Visual direction:
- Soft industrial gradient shell, quiet panels, high readability.
- State colors: running green/cyan, warning amber, fault red, disabled gray, manual override blue.
- Text must fit in Chinese and English; avoid dense tiny labels.
- Command buttons and indicators must look different.
- Keep navigation stable and alarm/status visible on primary operation screens.

Reference-image handling:
- Extract layout zones, spacing, palette, typography and component density.
- Recreate the design with editable WinCC objects.
- Use generated images as proof/reference only.
"@

$implementationPlan = @"
# Implementation Plan

1. Run or inspect plugin routing: `$pluginRoutingPath`
2. Read Agent plan: `$agentPlanPath`
3. Read project block/DB/HMI tag exports.
4. Generate or update screen map, faceplate map, tag contract and style guide.
5. Use imagegen when text-to-image or reference-guided design is requested.
6. Use Openness for supported engineering objects.
7. Use SiVArc when repeated stations/devices can be generated from rules.
8. Use reviewed TIA MCP or manual fallback only when the local API cannot cover the operation.
9. Compile/smoke-test on backup or clone before release.
"@

$pluginPlan = @"
# Plugin Invocation Plan

Plugin routing source:

```json
$pluginRoutingText
```

Routing rules:
- Use imagegen for visual concepts or reference-guided redesign.
- Use Siemens Openness for HMI tags, screen traversal, import/export and supported engineering objects.
- Use SiVArc when repeated devices/stations can be generated from PLC structures and templates.
- Use reviewed TIA MCP adapters only after source/provenance review and only on a cloned project.
- Use WinCC Unified GraphQL/runtime MCP for runtime read/subscribe validation on trusted endpoints; do not write tags or acknowledge alarms unless explicitly requested.
- Use CWC only for widgets that standard controls or faceplates cannot maintainably represent.
"@

$cwcFaceplatePackage = @"
# CWC And Faceplate Package

Faceplate candidates:
- FP_工位_Station
- FP_电机_Motor
- FP_气缸_Cylinder
- FP_变频器_Drive
- FP_报警条_AlarmStrip
- FP_参数组_ParameterGroup

CWC candidates:
- CWC_趋势矩阵_TrendMatrix for dense multi-value charts.
- CWC_诊断表_DiagnosticTable for searchable diagnostics.
- CWC_设备拓扑_DeviceTopology when a process map cannot be maintained with native shapes.

Packaging discipline:
- Keep operational commands in WinCC-native controls or well-reviewed faceplates when possible.
- CWC reads may be broader than CWC writes; every write must have authority, confirmation and audit notes.
- Store component names, tags, scripts and assets in this package before importing into TIA.
"@

$engineeringTasks = @"
{
  "schemaVersion": 1,
  "projectRoot": "$($root.Replace('\', '\\'))",
  "winccFlavor": "$winccFlavor",
  "referenceImage": "$(if ($hasReferenceImage) { ((Get-Item -LiteralPath $ReferenceImagePath).FullName).Replace('\', '\\') } else { "" })",
  "tasks": [
    { "id": "visual-analysis", "status": "PENDING", "output": "reference-analysis.md" },
    { "id": "screen-map", "status": "PENDING", "output": "screen-map.md" },
    { "id": "component-selection", "status": "PENDING", "output": "component-selection-matrix.md" },
    { "id": "tag-contract", "status": "PENDING", "output": "tag-contract.md" },
    { "id": "plugin-routing", "status": "PENDING", "output": "plugin-invocation-plan.md" },
    { "id": "faceplate-cwc-package", "status": "PENDING", "output": "cwc-faceplate-package.md" },
    { "id": "openness-sivarc-generation", "status": "BLOCKED_UNTIL_REVIEW", "output": "generated WinCC objects on clone" },
    { "id": "validation", "status": "PENDING", "output": "compile/runtime smoke report" }
  ],
  "releaseAllowed": false
}
"@

$safetyReview = @"
# Safety Review

Check:
- E-stop/STO/guard/light-curtain assumptions are documented and not invented by AI.
- Manual commands require correct mode and authority.
- Motion, homing, reset and recipe-write actions require confirmation where appropriate.
- Disabled commands show a concrete reason.
- Alarms remain visible from operation screens.
- Communication loss and stale data are visible.
- PLC command, feedback, interlock, alarm and diagnostic tags remain separated.

This package is an engineering aid. Certified safety logic must remain in the project's approved safety workflow.
"@

$files = @{
    "design-brief.md" = $designBrief
    "reference-analysis.md" = $referenceAnalysis
    "screen-map.md" = $screenMap
    "component-map.md" = $componentMap
    "component-selection-matrix.md" = $componentSelection
    "component-candidates.json" = $componentCandidates
    "tag-contract.md" = $tagContract
    "style-guide.md" = $styleGuide
    "implementation-plan.md" = $implementationPlan
    "plugin-invocation-plan.md" = $pluginPlan
    "cwc-faceplate-package.md" = $cwcFaceplatePackage
    "engineering-tasks.json" = $engineeringTasks
    "safety-review.md" = $safetyReview
}

foreach ($entry in $files.GetEnumerator()) {
    Write-Doc -Path (Join-Path $OutputDirectory $entry.Key) -Content $entry.Value
    Write-Doc -Path (Join-Path $latestDir $entry.Key) -Content $entry.Value
}

$index = @"
# WinCC Visual Package

Generated: $(Get-Date -Format s)
Project: `$root`
Output: `$OutputDirectory`

Files:
- design-brief.md
- reference-analysis.md
- screen-map.md
- component-map.md
- component-selection-matrix.md
- component-candidates.json
- tag-contract.md
- style-guide.md
- implementation-plan.md
- plugin-invocation-plan.md
- cwc-faceplate-package.md
- engineering-tasks.json
- safety-review.md
"@
Write-Doc -Path (Join-Path $OutputDirectory "README.md") -Content $index
Write-Doc -Path (Join-Path $latestDir "README.md") -Content $index

@"
{
  "status": "ok",
  "outputDirectory": "$($OutputDirectory.Replace('\', '\\'))",
  "latestDirectory": "$($latestDir.Replace('\', '\\'))"
}
"@
