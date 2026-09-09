param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    [string]$WorkflowConfigPath = "",
    [string]$TaskText = "",
    [string]$ReferenceImagePath = "",
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

function Add-Task {
    param(
        $Items,
        [string]$Id,
        [string]$Name,
        [string]$Route,
        [string]$InputArtifact,
        [string]$OutputArtifact,
        [string]$Gate,
        [string]$Safety
    )
    [void]$Items.Add([pscustomobject]@{
        id = $Id
        name = $Name
        route = $Route
        inputArtifact = $InputArtifact
        outputArtifact = $OutputArtifact
        gate = $Gate
        safety = $Safety
    })
}

$root = Resolve-ProjectDirectory -Path $ProjectPath
$workspaceRoot = Join-Path $root "PLC_Code"
if ([string]::IsNullOrWhiteSpace($WorkflowConfigPath)) { $WorkflowConfigPath = Join-Path $workspaceRoot "config\ai-workflow.json" }
$config = $null
if (Test-Path -LiteralPath $WorkflowConfigPath -PathType Leaf) {
    $config = Get-Content -LiteralPath $WorkflowConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
}
if ([string]::IsNullOrWhiteSpace($ReferenceImagePath)) {
    $ReferenceImagePath = Get-ConfigValue -Config $config -Path @("image", "referenceImage") -Fallback ""
}
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $workspaceRoot ("wincc\engineering-scaffold\" + (Get-Date -Format "yyyyMMdd-HHmmss"))
}
$latestDir = Join-Path $workspaceRoot "wincc\engineering-scaffold\latest"
New-Item -ItemType Directory -Path $OutputDirectory, $latestDir -Force | Out-Null

$visualRoot = Join-Path $workspaceRoot "wincc\tasks\latest"
$blueprintRoot = Join-Path $workspaceRoot "wincc\component-blueprints\latest"
$pluginRoutingPath = Join-Path $workspaceRoot "wincc\plugin-routing.json"
$tagContractPath = Join-Path $visualRoot "tag-contract.md"
$componentMapPath = Join-Path $visualRoot "component-map.md"
$componentBlueprintPath = Join-Path $blueprintRoot "component-blueprints.md"
$layoutPath = Join-Path $blueprintRoot "screen-layout-grid.json"
$sivarcBlueprintPath = Join-Path $blueprintRoot "sivarc-rule-blueprints.md"
$cwcManifestPath = Join-Path $blueprintRoot "cwc-package-manifest.json"
$hasReferenceImage = -not [string]::IsNullOrWhiteSpace($ReferenceImagePath) -and (Test-Path -LiteralPath $ReferenceImagePath -PathType Leaf)

$winccFlavor = Get-ConfigValue -Config $config -Path @("wincc", "flavor") -Fallback "auto"
$pluginPolicy = Get-ConfigValue -Config $config -Path @("wincc", "pluginPolicy") -Fallback "review-first"
$componentStrategy = Get-ConfigValue -Config $config -Path @("image", "componentStrategy") -Fallback "editable-wincc-first"
$graphqlUrl = Get-ConfigValue -Config $config -Path @("wincc", "graphqlUrl") -Fallback ""
$referenceImageValue = ""
$visualRootValue = ""
$pluginRoutingValue = ""
$tagContractValue = ""
$componentMapValue = ""
$componentBlueprintValue = ""
$layoutValue = ""
$sivarcBlueprintValue = ""
$cwcManifestValue = ""
if ($hasReferenceImage) { $referenceImageValue = (Get-Item -LiteralPath $ReferenceImagePath).FullName }
if (Test-Path -LiteralPath $visualRoot -PathType Container) { $visualRootValue = $visualRoot }
if (Test-Path -LiteralPath $pluginRoutingPath -PathType Leaf) { $pluginRoutingValue = $pluginRoutingPath }
if (Test-Path -LiteralPath $tagContractPath -PathType Leaf) { $tagContractValue = $tagContractPath }
if (Test-Path -LiteralPath $componentMapPath -PathType Leaf) { $componentMapValue = $componentMapPath }
if (Test-Path -LiteralPath $componentBlueprintPath -PathType Leaf) { $componentBlueprintValue = $componentBlueprintPath }
if (Test-Path -LiteralPath $layoutPath -PathType Leaf) { $layoutValue = $layoutPath }
if (Test-Path -LiteralPath $sivarcBlueprintPath -PathType Leaf) { $sivarcBlueprintValue = $sivarcBlueprintPath }
if (Test-Path -LiteralPath $cwcManifestPath -PathType Leaf) { $cwcManifestValue = $cwcManifestPath }

$tasks = New-Object System.Collections.ArrayList
Add-Task $tasks "preflight" "生成前置检查_Preflight" "Openness/SiVArc/read-only" "plugin-routing.json, project-model.json" "preflight-checklist.md" "TIA version, HMI device, PLC device, SiVArc license and compile readiness are known" "No production write"
Add-Task $tasks "screen-shell" "画面外壳_ScreenShell" "Openness or manual import scaffold" "screen-layout-grid.json, screen-map.md" "openness-screen-scaffold.ps1.todo.md" "Screen dimensions, navigation and alarm strip reviewed" "No command widgets until tag contract is approved"
Add-Task $tasks "hmi-tags" "HMI变量契约_HmiTags" "Openness tag import scaffold" "tag-contract.md" "hmi-tag-import-map.csv" "Cmd/Fb/Sts/Intlk/Alm/Par/Diag are separated" "No write tag doubles as feedback"
Add-Task $tasks "alarms" "报警工程_Alarms" "Openness alarm import scaffold" "tag-contract.md, safety-review.md" "alarm-import-map.csv" "Alarm class, acknowledge behavior and reset semantics reviewed" "Acknowledge must not clear physical fault"
Add-Task $tasks "faceplates" "面板与模板_Faceplates" "Existing faceplate, custom faceplate or SiVArc template" "component-blueprints.md" "faceplate-build-list.md" "Project naming and tag interface reviewed" "Motion/reset/recipe-write controls require authority"
Add-Task $tasks "sivarc" "SiVArc规则_SiVArcRules" "SiVArc rule scaffold" "sivarc-rule-blueprints.md, component map" "sivarc-generation-checklist.md" "SiVArc support, license and device names confirmed" "Generate only on clone for first run"
Add-Task $tasks "cwc" "自定义Web控件_CWC" "CWC package scaffold" "cwc-package-manifest.json" "cwc-build-review.md" "Source, license and sandbox behavior reviewed" "CWC write operations disabled by default"
Add-Task $tasks "runtime-smoke" "运行时冒烟_RuntimeSmoke" "WinCC Unified GraphQL or manual runtime checklist" "graphqlUrl/config, tag contract" "wincc-runtime-smoke-plan.md" "Trusted endpoint and read scope defined" "Write/ack requires explicit user intent"
Add-Task $tasks "clone-validation" "克隆验证_CloneValidation" "Openness compile / runtime smoke" "generated artifacts" "clone-validation-plan.md" "Clone compile, screen open, tag bindings and alarm/trend smoke pass" "No production apply"

$json = [pscustomobject]@{
    schemaVersion = 1
    generatedAt = (Get-Date).ToString("o")
    projectRoot = $root
    workflowConfigPath = $WorkflowConfigPath
    taskText = $TaskText
    winccFlavor = $winccFlavor
    pluginPolicy = $pluginPolicy
    componentStrategy = $componentStrategy
    graphqlUrl = $graphqlUrl
    referenceImage = $referenceImageValue
    inputs = [pscustomobject]@{
        visualPackage = $visualRootValue
        pluginRouting = $pluginRoutingValue
        tagContract = $tagContractValue
        componentMap = $componentMapValue
        componentBlueprints = $componentBlueprintValue
        layoutGrid = $layoutValue
        sivarcBlueprints = $sivarcBlueprintValue
        cwcManifest = $cwcManifestValue
    }
    tasks = @($tasks)
    releaseAllowed = $false
}

$jsonPath = Join-Path $OutputDirectory "wincc-engineering-scaffold.json"
$latestJsonPath = Join-Path $latestDir "wincc-engineering-scaffold.json"
$json | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
$json | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $latestJsonPath -Encoding UTF8

$taskCsvPath = Join-Path $OutputDirectory "engineering-task-list.csv"
$latestTaskCsvPath = Join-Path $latestDir "engineering-task-list.csv"
@($tasks) | Export-Csv -LiteralPath $taskCsvPath -NoTypeInformation -Encoding UTF8
@($tasks) | Export-Csv -LiteralPath $latestTaskCsvPath -NoTypeInformation -Encoding UTF8

$md = New-Object System.Text.StringBuilder
[void]$md.AppendLine("# WinCC Engineering Scaffold")
[void]$md.AppendLine()
[void]$md.AppendLine("- Project: ``$root``")
[void]$md.AppendLine("- Task: $TaskText")
[void]$md.AppendLine("- WinCC flavor: ``$winccFlavor``")
[void]$md.AppendLine("- Component strategy: ``$componentStrategy``")
[void]$md.AppendLine("- Reference image: ``$(if ($hasReferenceImage) { (Get-Item -LiteralPath $ReferenceImagePath).FullName } else { "none" })``")
[void]$md.AppendLine("- Generated: ``$(Get-Date -Format o)``")
[void]$md.AppendLine()
[void]$md.AppendLine("## Engineering Tasks")
[void]$md.AppendLine()
foreach ($task in $tasks) {
    [void]$md.AppendLine("### " + $task.name)
    [void]$md.AppendLine("- Route: " + $task.route)
    [void]$md.AppendLine("- Input: " + $task.inputArtifact)
    [void]$md.AppendLine("- Output: " + $task.outputArtifact)
    [void]$md.AppendLine("- Gate: " + $task.gate)
    [void]$md.AppendLine("- Safety: " + $task.safety)
    [void]$md.AppendLine()
}
[void]$md.AppendLine("## Current Input Excerpts")
[void]$md.AppendLine()
[void]$md.AppendLine("### Tag Contract")
[void]$md.AppendLine()
[void]$md.AppendLine('```text')
[void]$md.AppendLine((Read-ShortText -Path $tagContractPath -Max 1800))
[void]$md.AppendLine('```')
[void]$md.AppendLine()
[void]$md.AppendLine("### Component Blueprints")
[void]$md.AppendLine()
[void]$md.AppendLine('```text')
[void]$md.AppendLine((Read-ShortText -Path $componentBlueprintPath -Max 2200))
[void]$md.AppendLine('```')

$mdPath = Join-Path $OutputDirectory "wincc-engineering-scaffold.md"
$latestMdPath = Join-Path $latestDir "wincc-engineering-scaffold.md"
$md.ToString() | Set-Content -LiteralPath $mdPath -Encoding UTF8
$md.ToString() | Set-Content -LiteralPath $latestMdPath -Encoding UTF8

$preflight = @"
# WinCC Engineering Preflight Checklist

- TIA version and WinCC flavor are known.
- HMI device name and PLC device name are known.
- PLC blocks and hardware compile before SiVArc generation.
- Faceplate/template names and tag interfaces match the PLC DB/UDT contract.
- First engineering writes run on a backup or clone.
- Community MCP/tool binaries are not executed until source, license and provenance are reviewed.
"@
$preflight | Set-Content -LiteralPath (Join-Path $OutputDirectory "preflight-checklist.md") -Encoding UTF8
$preflight | Set-Content -LiteralPath (Join-Path $latestDir "preflight-checklist.md") -Encoding UTF8

$tagRows = @(
    [pscustomobject]@{ objectName = "BTN_启动_Start"; tag = "启动命令_StartCmd"; layer = "Cmd"; access = "write"; confirmation = "mode-authority"; note = "button command, feedback separate" },
    [pscustomobject]@{ objectName = "IND_运行_Run"; tag = "运行反馈_RunFb"; layer = "Fb"; access = "read"; confirmation = ""; note = "feedback indicator" },
    [pscustomobject]@{ objectName = "TXT_互锁原因_InterlockReason"; tag = "互锁原因_InterlockReason"; layer = "Intlk"; access = "read"; confirmation = ""; note = "show disabled reason" },
    [pscustomobject]@{ objectName = "ALM_当前报警_ActiveAlarm"; tag = "当前报警_ActiveAlarm"; layer = "Alm"; access = "read"; confirmation = ""; note = "alarm strip" },
    [pscustomobject]@{ objectName = "IO_速度设定_SpeedSp"; tag = "速度设定_SpeedSp"; layer = "Par"; access = "write"; confirmation = "authority-and-range"; note = "parameter write" }
)
$tagRows | Export-Csv -LiteralPath (Join-Path $OutputDirectory "hmi-tag-import-map.csv") -NoTypeInformation -Encoding UTF8
$tagRows | Export-Csv -LiteralPath (Join-Path $latestDir "hmi-tag-import-map.csv") -NoTypeInformation -Encoding UTF8

$alarmRows = @(
    [pscustomobject]@{ alarmName = "超时报警_TimeoutAlm"; class = "Fault"; triggerTag = "超时报警_TimeoutAlm"; ack = "required"; reset = "separate-reset-command" },
    [pscustomobject]@{ alarmName = "过载报警_OverloadAlm"; class = "Fault"; triggerTag = "过载报警_OverloadAlm"; ack = "required"; reset = "field-condition-first" },
    [pscustomobject]@{ alarmName = "通信故障_CommFault"; class = "Fault"; triggerTag = "通信故障_CommFault"; ack = "required"; reset = "auto-clear-after-healthy" }
)
$alarmRows | Export-Csv -LiteralPath (Join-Path $OutputDirectory "alarm-import-map.csv") -NoTypeInformation -Encoding UTF8
$alarmRows | Export-Csv -LiteralPath (Join-Path $latestDir "alarm-import-map.csv") -NoTypeInformation -Encoding UTF8

$faceplateList = @"
# Faceplate Build List

- FP_工位_Station: state, mode, interlock, fault, detail.
- FP_电机_Motor: start, stop, forward, reverse, run feedback, fault, interlock.
- FP_气缸_Cylinder: extend, retract, end sensors, timeout and air status.
- FP_变频器_Drive: enable, setpoint, feedback, status word, fault code and communication status.
- FP_参数组_ParameterGroup: grouped parameter writes with range and authority.
"@
$faceplateList | Set-Content -LiteralPath (Join-Path $OutputDirectory "faceplate-build-list.md") -Encoding UTF8
$faceplateList | Set-Content -LiteralPath (Join-Path $latestDir "faceplate-build-list.md") -Encoding UTF8

$sivarc = @"
# SiVArc Generation Checklist

- Confirm SiVArc is installed and licensed for the target TIA/WinCC version.
- Confirm the PLC program and hardware configuration compile before generation.
- Bind rule inputs to PLC DB/UDT names using Chinese_English naming.
- Generate repeated station/device cards from stable PLC structures.
- First generation target must be a clone; compare generated HMI object names before release.
"@
$sivarc | Set-Content -LiteralPath (Join-Path $OutputDirectory "sivarc-generation-checklist.md") -Encoding UTF8
$sivarc | Set-Content -LiteralPath (Join-Path $latestDir "sivarc-generation-checklist.md") -Encoding UTF8

$cwcReview = @"
# CWC Build Review

- Use only when native WinCC controls or faceplates cannot maintainably represent the widget.
- Review CWC source, third-party packages and license before import.
- Keep default CWC operations read-only.
- Any runtime write from CWC requires explicit authority, confirmation, audit tag and rollback note.
"@
$cwcReview | Set-Content -LiteralPath (Join-Path $OutputDirectory "cwc-build-review.md") -Encoding UTF8
$cwcReview | Set-Content -LiteralPath (Join-Path $latestDir "cwc-build-review.md") -Encoding UTF8

$runtimeSmoke = @"
# WinCC Runtime Smoke Plan

- Endpoint: `$graphqlUrl`
- Default scope: read/query/subscribe only.
- Check PLC connection tag, mode tag, active alarm tag, one motor card, one trend and one parameter value.
- Record request, timestamp, returned values and screenshots/logs as evidence.
- Write, acknowledge or reset actions require explicit user instruction for a trusted runtime.
"@
$runtimeSmoke | Set-Content -LiteralPath (Join-Path $OutputDirectory "wincc-runtime-smoke-plan.md") -Encoding UTF8
$runtimeSmoke | Set-Content -LiteralPath (Join-Path $latestDir "wincc-runtime-smoke-plan.md") -Encoding UTF8

$cloneValidation = @"
# Clone Validation Plan

1. Back up or clone the TIA project.
2. Import generated HMI tags, alarms, screens, faceplates or SiVArc rules only into the clone.
3. Compile PLC and HMI where supported.
4. Open generated screens and check component placement, tag bindings, alarm strip, trends and command authority.
5. Re-export generated artifacts or capture screenshots/logs.
6. Build review package and wait for explicit production-apply intent.
"@
$cloneValidation | Set-Content -LiteralPath (Join-Path $OutputDirectory "clone-validation-plan.md") -Encoding UTF8
$cloneValidation | Set-Content -LiteralPath (Join-Path $latestDir "clone-validation-plan.md") -Encoding UTF8

[pscustomobject]@{
    status = "ok"
    outputDirectory = $OutputDirectory
    latestDirectory = $latestDir
    scaffold = $mdPath
    scaffoldJson = $jsonPath
    taskCount = $tasks.Count
    releaseAllowed = $false
} | ConvertTo-Json -Depth 6
