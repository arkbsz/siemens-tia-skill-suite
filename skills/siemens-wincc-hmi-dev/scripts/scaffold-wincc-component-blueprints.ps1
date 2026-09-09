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

function Add-Blueprint {
    param(
        $Items,
        [string]$Id,
        [string]$Name,
        [string]$Kind,
        [string]$UseFor,
        [string[]]$Tags,
        [string[]]$Objects,
        [string]$Layout,
        [string]$Safety,
        [string]$ImplementationRoute
    )

    [void]$Items.Add([pscustomobject]@{
        id = $Id
        name = $Name
        kind = $Kind
        useFor = $UseFor
        tags = @($Tags)
        objects = @($Objects)
        layout = $Layout
        safety = $Safety
        implementationRoute = $ImplementationRoute
    })
}

$root = Resolve-ProjectDirectory -Path $ProjectPath
$workspaceRoot = Join-Path $root "PLC_Code"
if ([string]::IsNullOrWhiteSpace($WorkflowConfigPath)) { $WorkflowConfigPath = Join-Path $workspaceRoot "config\ai-workflow.json" }
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $workspaceRoot ("wincc\component-blueprints\" + (Get-Date -Format "yyyyMMdd-HHmmss"))
}
$latestDir = Join-Path $workspaceRoot "wincc\component-blueprints\latest"
New-Item -ItemType Directory -Path $OutputDirectory, $latestDir -Force | Out-Null

if ([string]::IsNullOrWhiteSpace($ReferenceImagePath) -and (Test-Path -LiteralPath $WorkflowConfigPath -PathType Leaf)) {
    try {
        $config = Get-Content -LiteralPath $WorkflowConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($config.PSObject.Properties.Name -contains "image" -and $config.image.PSObject.Properties.Name -contains "referenceImage") {
            $ReferenceImagePath = [string]$config.image.referenceImage
        }
    }
    catch {
    }
}

$hasReferenceImage = -not [string]::IsNullOrWhiteSpace($ReferenceImagePath) -and (Test-Path -LiteralPath $ReferenceImagePath -PathType Leaf)
$visualPackageRoot = Join-Path $workspaceRoot "wincc\tasks\latest"
$pluginRoutingPath = Join-Path $workspaceRoot "wincc\plugin-routing.json"
$tagContractPath = Join-Path $visualPackageRoot "tag-contract.md"
$componentMapPath = Join-Path $visualPackageRoot "component-map.md"
$styleGuidePath = Join-Path $visualPackageRoot "style-guide.md"
$referenceAnalysisPath = Join-Path $visualPackageRoot "reference-analysis.md"
$referenceImageValue = ""
$pluginRoutingValue = ""
$visualPackageValue = ""
$tagContractValue = ""
$componentMapValue = ""
$styleGuideValue = ""
$referenceAnalysisValue = ""
if ($hasReferenceImage) { $referenceImageValue = (Get-Item -LiteralPath $ReferenceImagePath).FullName }
if (Test-Path -LiteralPath $pluginRoutingPath -PathType Leaf) { $pluginRoutingValue = $pluginRoutingPath }
if (Test-Path -LiteralPath $visualPackageRoot -PathType Container) { $visualPackageValue = $visualPackageRoot }
if (Test-Path -LiteralPath $tagContractPath -PathType Leaf) { $tagContractValue = $tagContractPath }
if (Test-Path -LiteralPath $componentMapPath -PathType Leaf) { $componentMapValue = $componentMapPath }
if (Test-Path -LiteralPath $styleGuidePath -PathType Leaf) { $styleGuideValue = $styleGuidePath }
if (Test-Path -LiteralPath $referenceAnalysisPath -PathType Leaf) { $referenceAnalysisValue = $referenceAnalysisPath }

$blueprints = New-Object System.Collections.ArrayList
Add-Blueprint $blueprints "screen-shell" "画面外壳_ScreenShell" "screen-template" "总览、手动、自动、报警、趋势、参数、维护、诊断等所有主画面" @("系统状态_SystemSts", "当前模式_CurrentMode", "PLC连接_PlcConnected", "当前用户_CurrentUser") @("TXT_标题_Title", "NAV_主导航_MainNav", "IND_PLC连接_PlcLink", "TXT_时间_Time") "顶部标题 + 左/顶部导航 + 常驻报警条 + 中央内容区" "报警条保持可见；导航不遮挡操作区域" "Openness screen scaffold or SiVArc template"
Add-Blueprint $blueprints "alarm-strip" "报警条_AlarmStrip" "faceplate" "所有操作画面常驻报警、警告、首出和确认状态" @("当前报警_ActiveAlarm", "当前警告_ActiveWarning", "首出故障_FirstOutFault", "确认命令_AckCmd", "复位命令_ResetCmd") @("IND_报警_Fault", "TXT_报警文本_AlarmText", "BTN_确认_Ack", "BTN_复位_Reset") "高对比窄条，放在顶部或底部固定区域" "确认不等于消除故障；复位需要权限和安全状态" "Standard AlarmView first, custom faceplate if project style requires"
Add-Blueprint $blueprints "station-card" "工位卡_StationCard" "faceplate" "重复工位、搬运站、加工站、检测站状态卡片" @("工位状态_StationSts", "自动状态_AutoSts", "手动状态_ManualSts", "互锁允许_InterlockOk", "故障报警_FaultAlm") @("CARD_工位_Station", "IND_状态_State", "TXT_互锁原因_InterlockReason", "BTN_详情_Detail") "卡片网格或流程图节点，按物理工位顺序排列" "禁用命令要显示互锁原因；故障状态不可只靠颜色" "Existing faceplate, then SiVArc repeated object"
Add-Blueprint $blueprints "motor-faceplate" "电机面板_MotorFaceplate" "faceplate" "单向/正反转电机、输送线、泵和风机" @("启动命令_StartCmd", "停止命令_StopCmd", "正转命令_ForwardCmd", "反转命令_ReverseCmd", "运行反馈_RunFb", "过载报警_OverloadAlm", "互锁允许_InterlockOk") @("BTN_启动_Start", "BTN_停止_Stop", "BTN_正转_Forward", "BTN_反转_Reverse", "IND_运行_Run", "IND_故障_Fault") "按钮与反馈左右分离，正反转互斥显示" "正反转必须互锁；命令和反馈必须分离" "Native buttons/lamps or faceplate; bind to PLC UDT_电机_Motor"
Add-Blueprint $blueprints "cylinder-faceplate" "气缸面板_CylinderFaceplate" "faceplate" "伸出/缩回气缸、夹爪、挡停、定位机构" @("伸出命令_ExtendCmd", "缩回命令_RetractCmd", "伸出到位_ExtendFb", "缩回到位_RetractFb", "超时报警_TimeoutAlm", "气压正常_AirOk") @("BTN_伸出_Extend", "BTN_缩回_Retract", "IND_伸出到位_Extended", "IND_缩回到位_Retracted", "TXT_超时_Timeout") "机械示意 + 双端到位 + 操作按钮成组" "伸缩互锁、超时、气压和手动权限必须显示" "Native controls or reusable faceplate"
Add-Blueprint $blueprints "drive-faceplate" "驱动面板_DriveFaceplate" "faceplate" "变频器、伺服使能、速度设定和状态诊断" @("使能命令_EnableCmd", "速度设定_SpeedSp", "速度反馈_SpeedFb", "状态字_StatusWord", "故障代码_FaultCode", "通信状态_CommSts") @("BTN_使能_Enable", "IO_速度设定_SpeedSp", "IO_速度反馈_SpeedFb", "TXT_故障代码_FaultCode", "IND_通信_Comm") "设定/反馈/状态字分层，故障代码可点开详情" "参数写入需权限；通信丢失和陈旧数据必须报警" "Faceplate plus trend; CWC only for dense diagnostics"
Add-Blueprint $blueprints "parameter-panel" "参数面板_ParameterPanel" "screen-section" "配方、工艺参数、时间、速度、限值设置" @("参数值_ParameterValue", "最小值_Min", "最大值_Max", "单位_Unit", "写入命令_WriteCmd", "权限级别_AuthorityLevel") @("IO_参数_Parameter", "TXT_单位_Unit", "BTN_写入_Write", "DLG_确认_Confirm") "表格分组，显示单位、范围和最后修改" "写入需权限、范围检查和确认；不可直接写安全参数" "Native IOFields/table first; CWC table only after review"
Add-Blueprint $blueprints "trend-panel" "趋势面板_TrendPanel" "screen-section" "速度、电流、压力、位置、周期时间和关键过程值趋势" @("过程值_ProcessValue", "设定值_Setpoint", "上限_HighLimit", "下限_LowLimit", "报警状态_AlarmSts") @("TrendView_趋势_Trend", "LEG_图例_Legend", "TXT_单位_Unit") "趋势区域留足高度，图例和单位清晰" "趋势默认只读；写设定值应跳转到参数面板并确认" "Native TrendView preferred"
Add-Blueprint $blueprints "diagnostic-table" "诊断表_DiagnosticTable" "custom-component" "模块、通信、状态字、报警历史和 Agent 验证结果" @("诊断列表_DiagnosticList", "模块状态_ModuleSts", "通信状态_CommSts", "状态字_StatusWord", "更新时间_UpdateTime") @("TABLE_诊断_Diagnostics", "TXT_状态字_StatusWord", "BTN_刷新_Refresh") "可搜索表格或分层列表，适合维护页面" "运行时写入默认禁用；刷新只读优先" "Native list/table first; CWC if Unified widget needs rich filtering"

$json = [pscustomobject]@{
    schemaVersion = 1
    generatedAt = (Get-Date).ToString("o")
    projectRoot = $root
    workflowConfigPath = $WorkflowConfigPath
    taskText = $TaskText
    referenceImage = $referenceImageValue
    namingRule = "中文_English"
    selectionOrder = @("existing-project-faceplate", "standard-wincc-control", "sivarc-rule", "custom-faceplate", "custom-web-control")
    blueprints = @($blueprints)
    inputs = [pscustomobject]@{
        pluginRouting = $pluginRoutingValue
        visualPackage = $visualPackageValue
        tagContract = $tagContractValue
        componentMap = $componentMapValue
        styleGuide = $styleGuideValue
        referenceAnalysis = $referenceAnalysisValue
    }
    releaseAllowed = $false
}

$jsonPath = Join-Path $OutputDirectory "component-blueprints.json"
$latestJsonPath = Join-Path $latestDir "component-blueprints.json"
$json | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
$json | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $latestJsonPath -Encoding UTF8

$md = New-Object System.Text.StringBuilder
[void]$md.AppendLine("# WinCC Component Blueprints")
[void]$md.AppendLine()
[void]$md.AppendLine("- Project: ``$root``")
[void]$md.AppendLine("- Task: $TaskText")
$referenceImageLabel = "none"
if ($hasReferenceImage) { $referenceImageLabel = (Get-Item -LiteralPath $ReferenceImagePath).FullName }
[void]$md.AppendLine("- Reference image: ``$referenceImageLabel``")
[void]$md.AppendLine("- Naming: ``中文_English``")
[void]$md.AppendLine("- Generated: ``$(Get-Date -Format o)``")
[void]$md.AppendLine()
[void]$md.AppendLine("## Selection Order")
[void]$md.AppendLine()
[void]$md.AppendLine("1. Existing project faceplates aligned with PLC DB/UDT contracts.")
[void]$md.AppendLine("2. Standard WinCC controls for buttons, lamps, I/O fields, trends, alarm views and navigation.")
[void]$md.AppendLine("3. SiVArc rules for repeated devices, stations and screens.")
[void]$md.AppendLine("4. Custom faceplates for reusable station/device cards.")
[void]$md.AppendLine("5. CWC only when native controls cannot represent the required widget cleanly.")
[void]$md.AppendLine()
[void]$md.AppendLine("## Blueprint Matrix")
[void]$md.AppendLine()
[void]$md.AppendLine("| Blueprint | Kind | Use For | Key Tags | Main Objects | Route | Safety |")
[void]$md.AppendLine("| --- | --- | --- | --- | --- | --- | --- |")
foreach ($bp in $blueprints) {
    $tagText = [string]::Join(", ", [string[]]$bp.tags)
    $objectText = [string]::Join(", ", [string[]]$bp.objects)
    [void]$md.AppendLine("| $($bp.name) | $($bp.kind) | $($bp.useFor) | $tagText | $objectText | $($bp.implementationRoute) | $($bp.safety) |")
}
[void]$md.AppendLine()
[void]$md.AppendLine("## Source Package Excerpts")
[void]$md.AppendLine()
[void]$md.AppendLine("### Reference Analysis")
[void]$md.AppendLine()
[void]$md.AppendLine('```text')
[void]$md.AppendLine((Read-ShortText -Path $referenceAnalysisPath -Max 1600))
[void]$md.AppendLine('```')
[void]$md.AppendLine()
[void]$md.AppendLine("### Tag Contract")
[void]$md.AppendLine()
[void]$md.AppendLine('```text')
[void]$md.AppendLine((Read-ShortText -Path $tagContractPath -Max 1600))
[void]$md.AppendLine('```')

$mdPath = Join-Path $OutputDirectory "component-blueprints.md"
$latestMdPath = Join-Path $latestDir "component-blueprints.md"
$md.ToString() | Set-Content -LiteralPath $mdPath -Encoding UTF8
$md.ToString() | Set-Content -LiteralPath $latestMdPath -Encoding UTF8

$layout = [pscustomobject]@{
    schemaVersion = 1
    screenSize = [pscustomobject]@{
        width = 1920
        height = 1080
    }
    zones = @(
        [pscustomobject]@{ id = "header"; name = "顶部状态_Header"; x = 0; y = 0; w = 1920; h = 92 },
        [pscustomobject]@{ id = "alarm"; name = "报警条_AlarmStrip"; x = 0; y = 92; w = 1920; h = 58 },
        [pscustomobject]@{ id = "nav"; name = "导航_Navigation"; x = 0; y = 150; w = 250; h = 930 },
        [pscustomobject]@{ id = "content"; name = "主内容_MainContent"; x = 250; y = 150; w = 1670; h = 930 }
    )
    spacing = 18
    cornerRadius = 14
}
$layoutJson = $layout | ConvertTo-Json -Depth 6
$layoutJson | Set-Content -LiteralPath (Join-Path $OutputDirectory "screen-layout-grid.json") -Encoding UTF8
$layoutJson | Set-Content -LiteralPath (Join-Path $latestDir "screen-layout-grid.json") -Encoding UTF8

$sivarc = @"
# SiVArc Rule Blueprints

- Generate one `工位卡_StationCard` per station/device UDT instance.
- Generate one motor/cylinder/drive faceplate for each matching PLC DB member.
- Bind commands only to `*_Cmd` tags and feedback only to `*_Fb` or `*_Sts` tags.
- Put repeated objects into the content zone from `screen-layout-grid.json`.
- Keep the common `报警条_AlarmStrip` on every operation screen.
- First run SiVArc generation only on a cloned project, then compile and compare generated HMI object names.
"@
$sivarc | Set-Content -LiteralPath (Join-Path $OutputDirectory "sivarc-rule-blueprints.md") -Encoding UTF8
$sivarc | Set-Content -LiteralPath (Join-Path $latestDir "sivarc-rule-blueprints.md") -Encoding UTF8

$cwcManifest = [pscustomobject]@{
    schemaVersion = 1
    allowedUse = "visualization-heavy or table-heavy Unified widgets that native controls cannot maintain cleanly"
    defaultPolicy = "prefer native WinCC objects; require source and license review before CWC import"
    candidateComponents = @(
        "CWC_诊断表_DiagnosticTable",
        "CWC_趋势矩阵_TrendMatrix",
        "CWC_设备拓扑_DeviceTopology"
    )
    releaseAllowed = $false
}
$cwc = $cwcManifest | ConvertTo-Json -Depth 6
$cwc | Set-Content -LiteralPath (Join-Path $OutputDirectory "cwc-package-manifest.json") -Encoding UTF8
$cwc | Set-Content -LiteralPath (Join-Path $latestDir "cwc-package-manifest.json") -Encoding UTF8

[pscustomobject]@{
    status = "ok"
    outputDirectory = $OutputDirectory
    latestDirectory = $latestDir
    blueprints = $mdPath
    blueprintsJson = $jsonPath
    blueprintCount = $blueprints.Count
    releaseAllowed = $false
} | ConvertTo-Json -Depth 6

