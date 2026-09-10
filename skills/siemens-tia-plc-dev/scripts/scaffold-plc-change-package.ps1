param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    [string]$WorkflowConfigPath = "",
    [string]$TaskText = "",
    [string]$Workflow = "auto",
    [string]$SourceXml = "",
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

function ConvertTo-JsonString {
    param([string]$Value)
    if ($null -eq $Value) { $Value = "" }
    $Value = $Value.Replace("\", "\\").Replace('"', '\"').Replace("`r", "\r").Replace("`n", "\n").Replace("`t", "\t")
    return '"' + $Value + '"'
}

$root = Resolve-ProjectDirectory -Path $ProjectPath
$workspaceRoot = Join-Path $root "PLC_Code"
if ([string]::IsNullOrWhiteSpace($WorkflowConfigPath)) { $WorkflowConfigPath = Join-Path $workspaceRoot "config\ai-workflow.json" }
$config = $null
if (Test-Path -LiteralPath $WorkflowConfigPath) { $config = Get-Content -LiteralPath $WorkflowConfigPath -Raw | ConvertFrom-Json }

$workflowName = Get-ConfigValue -Config $config -Path @("routing", "workflow") -Fallback $Workflow
$languagePreference = Get-ConfigValue -Config $config -Path @("routing", "languagePreference") -Fallback "LAD-first"
$safetyMode = Get-ConfigValue -Config $config -Path @("safety", "safetyMode") -Fallback "clone-compile"
$plcName = Get-ConfigValue -Config $config -Path @("tia", "plcName") -Fallback "PLC_1"
$stepTimeout = Get-ConfigValue -Config $config -Path @("tia", "stepTimeoutSeconds") -Fallback "600"
# Generated change-package commands must follow the active skill package,
# including the protected EXE runtime, instead of assuming a user install.
$invokePath = Join-Path $PSScriptRoot "invoke-siemens-plc-dev.ps1"

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $workspaceRoot "changes\$stamp-plc-change-package"
}
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $OutputDirectory "lad-json") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $OutputDirectory "scl-sources") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $OutputDirectory "db-sources") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $OutputDirectory "outputs") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $OutputDirectory "reports") -Force | Out-Null

$latestDir = Join-Path $workspaceRoot "changes\latest-plc-change-package"
New-Item -ItemType Directory -Path $latestDir -Force | Out-Null

$latestBlockList = ""
$runsRoot = Join-Path $workspaceRoot "runs"
if (Test-Path -LiteralPath $runsRoot) {
    $latestBlockListPath = Get-ChildItem -LiteralPath $runsRoot -Directory -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        ForEach-Object { Join-Path $_.FullName "reports\block-list.txt" } |
        Where-Object { Test-Path -LiteralPath $_ } |
        Select-Object -First 1
    if ($latestBlockListPath) { $latestBlockList = Get-Content -LiteralPath $latestBlockListPath -Raw -ErrorAction SilentlyContinue }
}

$readme = @"
# PLC Change Package

Project: `$root`
PLC: `$plcName`
Workflow: `$workflowName` / `$Workflow`
Language preference: `$languagePreference`
Safety mode: `$safetyMode`
Source XML: `$(if (Test-Path -LiteralPath $SourceXml) { (Get-Item -LiteralPath $SourceXml).FullName } else { "none" })`
Created: $(Get-Date -Format s)

Task:
$TaskText

Use this package as the local workbench editing unit. Fill the contract first, then generate LAD JSON/SCL/DB sources, then run verification on a cloned TIA project before any production write.

Files:
- block-contract.md
- naming-map.md
- lad-json/network-template.json
- scl-sources/README.md
- db-sources/README.md
- import-manifest.json
- verification-plan.md
- safety-risk-assessment.md
- reports/README.md
"@

$contract = @"
# Block And Data Contract

Design order:
1. Identify affected devices, stations, blocks, DBs, UDTs, HMI tags and alarms.
2. Separate commands, feedback, status, interlocks, alarms, parameters and diagnostics.
3. Choose implementation route per instruction family.
4. Keep maintenance-facing mode, permissive, latch, timer, counter and sequence visibility in LAD where practical.
5. Put arithmetic, conversion, string, array, recipe and protocol-heavy logic in SCL.

Suggested layers:
- Command_Cmd: operator or sequence command.
- Feedback_Fb: real input or drive/device response.
- Status_Sts: derived machine or station state.
- Interlock_Intlk: permissive and inhibit information.
- Alarm_Alm: latched fault or warning.
- Parameter_Par: retained setpoint/timer/configuration.
- Diagnostic_Diag: status words, counters, last error and timestamps.

Latest block list excerpt:

```text
$latestBlockList
```
"@

$naming = @'
# Naming Map

Rule: 中文_English, short, searchable and stable.

Block examples:
- FC_主循环_MainCycle
- FB_电机控制_MotorControl
- FB_轴控制_AxisControl
- FC_通讯诊断_CommDiag
- DB_参数_Parameters
- DB_报警_Alarms
- UDT_设备状态_DeviceState

Variable examples:
- 启动命令_StartCmd
- 停止命令_StopCmd
- 正转命令_ForwardCmd
- 反转命令_ReverseCmd
- 运行反馈_RunFb
- 故障状态_FaultSts
- 互锁允许_InterlockOk
- 复位请求_ResetReq
- 超时时间_TimeoutTime
- 状态字_StatusWord
'@

$ladTemplate = @'
{
  "schemaVersion": 1,
  "title": "网络标题_NetworkTitle",
  "comment": "写清楚动作目的、互锁条件、故障保持和复位条件。",
  "conditions": [
    { "type": "NO", "symbol": "启动命令_StartCmd", "scope": "GlobalVariable" },
    { "type": "NC", "symbol": "急停状态_EStopSts", "scope": "GlobalVariable" },
    { "type": "NO", "symbol": "互锁允许_InterlockOk", "scope": "GlobalVariable" }
  ],
  "actions": [
    { "type": "COIL", "symbol": "输出命令_OutputCmd", "scope": "GlobalVariable" }
  ]
}
'@

$sclReadme = @"
# SCL Sources

Use SCL for:
- analog scaling and limiting
- conversion and bit packing
- string/array handling
- recipe buffering
- protocol frame parsing
- dense algorithms that would make LAD unreadable

Keep a small LAD-facing interface for commands, interlocks, status and alarms.
"@

$dbReadme = @"
# DB Sources

Create DB/UDT changes before program logic when the task changes interfaces.

Required separation:
- command
- feedback
- status
- interlock
- alarm
- parameter
- diagnostic

Do not reuse one tag as both command and feedback.
"@

$naming = @(
    "# Naming Map",
    "",
    "Rule: 中文_English, short, searchable and stable.",
    "",
    "Block examples:",
    "- FC_主循环_MainCycle",
    "- FB_电机控制_MotorControl",
    "- FB_轴控制_AxisControl",
    "- FC_通讯诊断_CommDiag",
    "- DB_参数_Parameters",
    "- DB_报警_Alarms",
    "- UDT_设备状态_DeviceState",
    "",
    "Variable examples:",
    "- 启动命令_StartCmd",
    "- 停止命令_StopCmd",
    "- 正转命令_ForwardCmd",
    "- 反转命令_ReverseCmd",
    "- 运行反馈_RunFb",
    "- 故障状态_FaultSts",
    "- 互锁允许_InterlockOk",
    "- 复位请求_ResetReq",
    "- 超时时间_TimeoutTime",
    "- 状态字_StatusWord"
) -join [Environment]::NewLine

$ladTemplate = @(
    "{",
    "  ""schemaVersion"": 1,",
    "  ""title"": ""网络标题_NetworkTitle"",",
    "  ""comment"": ""写清楚动作目的、互锁条件、故障保持和复位条件。"",",
    "  ""conditions"": [",
    "    { ""type"": ""NO"", ""symbol"": ""启动命令_StartCmd"", ""scope"": ""GlobalVariable"" },",
    "    { ""type"": ""NC"", ""symbol"": ""急停状态_EStopSts"", ""scope"": ""GlobalVariable"" },",
    "    { ""type"": ""NO"", ""symbol"": ""互锁允许_InterlockOk"", ""scope"": ""GlobalVariable"" }",
    "  ],",
    "  ""actions"": [",
    "    { ""type"": ""COIL"", ""symbol"": ""输出命令_OutputCmd"", ""scope"": ""GlobalVariable"" }",
    "  ]",
    "}"
) -join [Environment]::NewLine

$sclReadme = @(
    "# SCL Sources",
    "",
    "Use SCL for:",
    "- analog scaling and limiting",
    "- conversion and bit packing",
    "- string/array handling",
    "- recipe buffering",
    "- protocol frame parsing",
    "- dense algorithms that would make LAD unreadable",
    "",
    "Keep a small LAD-facing interface for commands, interlocks, status and alarms."
) -join [Environment]::NewLine

$manifest = New-Object System.Text.StringBuilder
[void]$manifest.AppendLine("{")
[void]$manifest.AppendLine('  "schemaVersion": 1,')
[void]$manifest.AppendLine('  "projectRoot": ' + (ConvertTo-JsonString $root) + ',')
[void]$manifest.AppendLine('  "plcName": ' + (ConvertTo-JsonString $plcName) + ',')
[void]$manifest.AppendLine('  "workflow": ' + (ConvertTo-JsonString $Workflow) + ',')
[void]$manifest.AppendLine('  "sourceXml": ' + (ConvertTo-JsonString $SourceXml) + ',')
[void]$manifest.AppendLine('  "ladJson": "lad-json/network-template.json",')
[void]$manifest.AppendLine('  "generatedXml": "outputs/generated-block.xml",')
[void]$manifest.AppendLine('  "supportingSources": ["scl-sources", "db-sources"],')
[void]$manifest.AppendLine('  "verifyCommand": ' + (ConvertTo-JsonString ("powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$invokePath`" write-cycle -ProjectPath `"$root`" -InputXml `"outputs\generated-block.xml`" -PlcName `"$plcName`" -StepTimeoutSeconds $stepTimeout")) + ',')
[void]$manifest.AppendLine('  "productionWriteAllowed": false')
[void]$manifest.AppendLine("}")

$verification = @"
# Verification Plan

1. Run `doctor` and stop live write work if Openness is not ready.
2. Run `read-cycle` if exported block and DB summaries are stale.
3. Generate or edit LAD XML/SCL/DB sources inside this package.
4. Run `summarize-lad` for every generated LAD XML.
5. Run `write-cycle` against a cloned project with timeout `$stepTimeout`.
6. Re-export and compare affected blocks.
7. Review safety-risk-assessment.md before release.
8. Use `apply-release` only after explicit production-write confirmation.
"@

$risk = @"
# Safety Risk Assessment

Checklist:
- E-stop, STO, guard door, light curtain and safety PLC assumptions are identified.
- Manual commands are mode- and authority-gated.
- Forward/reverse, extend/retract, open/close and jog directions are mutually exclusive.
- Reset, homing, recipe write and force-like actions are confirmed or access-controlled.
- Feedback mismatch, timeout and stale communication states generate visible alarms.
- HMI command tags are separated from feedback and status tags.
- Generated logic has been compiled on a clone before production release.

AI-generated logic is not certified safety logic. Safety functions must follow the project's approved safety engineering and validation workflow.
"@

$reports = @"
# Reports

Place compile logs, LAD summaries, readback diffs, risk notes and release notes here.
"@

Write-Doc -Path (Join-Path $OutputDirectory "README.md") -Content $readme
Write-Doc -Path (Join-Path $OutputDirectory "block-contract.md") -Content $contract
Write-Doc -Path (Join-Path $OutputDirectory "naming-map.md") -Content $naming
Write-Doc -Path (Join-Path $OutputDirectory "lad-json\network-template.json") -Content $ladTemplate
Write-Doc -Path (Join-Path $OutputDirectory "scl-sources\README.md") -Content $sclReadme
Write-Doc -Path (Join-Path $OutputDirectory "db-sources\README.md") -Content $dbReadme
Write-Doc -Path (Join-Path $OutputDirectory "import-manifest.json") -Content $manifest.ToString()
Write-Doc -Path (Join-Path $OutputDirectory "verification-plan.md") -Content $verification
Write-Doc -Path (Join-Path $OutputDirectory "safety-risk-assessment.md") -Content $risk
Write-Doc -Path (Join-Path $OutputDirectory "reports\README.md") -Content $reports

New-Item -ItemType Directory -Path (Join-Path $latestDir "lad-json") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $latestDir "scl-sources") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $latestDir "db-sources") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $latestDir "outputs") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $latestDir "reports") -Force | Out-Null
Write-Doc -Path (Join-Path $latestDir "README.md") -Content $readme
Write-Doc -Path (Join-Path $latestDir "block-contract.md") -Content $contract
Write-Doc -Path (Join-Path $latestDir "naming-map.md") -Content $naming
Write-Doc -Path (Join-Path $latestDir "lad-json\network-template.json") -Content $ladTemplate
Write-Doc -Path (Join-Path $latestDir "scl-sources\README.md") -Content $sclReadme
Write-Doc -Path (Join-Path $latestDir "db-sources\README.md") -Content $dbReadme
Write-Doc -Path (Join-Path $latestDir "import-manifest.json") -Content $manifest.ToString()
Write-Doc -Path (Join-Path $latestDir "verification-plan.md") -Content $verification
Write-Doc -Path (Join-Path $latestDir "safety-risk-assessment.md") -Content $risk
Write-Doc -Path (Join-Path $latestDir "reports\README.md") -Content $reports

@"
{
  "status": "ok",
  "outputDirectory": "$($OutputDirectory.Replace('\', '\\'))",
  "latestDirectory": "$($latestDir.Replace('\', '\\'))"
}
"@
