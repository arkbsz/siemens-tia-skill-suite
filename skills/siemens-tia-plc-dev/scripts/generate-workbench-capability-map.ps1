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

function Add-Capability {
    param(
        [System.Collections.Generic.List[object]]$Items,
        [string]$Id,
        [string]$Name,
        [string]$Status,
        [string]$WorkbenchEntry,
        [string]$BackingCommand,
        [string]$Artifacts,
        [string]$Validation,
        [string]$NativeTiaStillNeeded,
        [string]$NextStep
    )

    [void]$Items.Add([pscustomobject]@{
        id = $Id
        name = $Name
        status = $Status
        workbenchEntry = $WorkbenchEntry
        backingCommand = $BackingCommand
        artifacts = $Artifacts
        validation = $Validation
        nativeTiaStillNeeded = $NativeTiaStillNeeded
        nextStep = $NextStep
    })
}

function Test-PathState {
    param([string]$Path, [string]$WhenExists, [string]$WhenMissing)
    if (Test-Path -LiteralPath $Path) { return $WhenExists }
    return $WhenMissing
}

$root = Resolve-ProjectDirectory -Path $ProjectPath
$workspaceRoot = Join-Path $root "PLC_Code"
if ([string]::IsNullOrWhiteSpace($WorkflowConfigPath)) { $WorkflowConfigPath = Join-Path $workspaceRoot "config\ai-workflow.json" }
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $workspaceRoot ("workbench\capabilities\" + (Get-Date -Format "yyyyMMdd-HHmmss"))
}
$latestDir = Join-Path $workspaceRoot "workbench\capabilities\latest"
New-Item -ItemType Directory -Path $OutputDirectory, $latestDir -Force | Out-Null

$projectModel = Join-Path $workspaceRoot "workbench\context\latest\project-model.json"
$agentContext = Join-Path $workspaceRoot "workbench\context\latest\agent-context.md"
$knowledgeBrief = Join-Path $workspaceRoot "knowledge\packs\latest\knowledge-brief.md"
$instructionRoute = Join-Path $workspaceRoot "plc\instruction-plans\latest\instruction-route-table.md"
$instructionCookbook = Join-Path $workspaceRoot "plc\instruction-cookbook\latest\instruction-cookbook.md"
$winccPackage = Join-Path $workspaceRoot "wincc\tasks\latest\README.md"
$winccComponentBlueprints = Join-Path $workspaceRoot "wincc\component-blueprints\latest\component-blueprints.md"
$winccEngineeringScaffold = Join-Path $workspaceRoot "wincc\engineering-scaffold\latest\wincc-engineering-scaffold.md"
$simulationPackage = Join-Path $workspaceRoot "simulation\latest\simulation-package.md"
$pluginRouting = Join-Path $workspaceRoot "wincc\plugin-routing.json"
$queueJson = Join-Path $workspaceRoot "agent-queues\latest\queue.json"
$dashboard = Join-Path $workspaceRoot "workbench\latest\dashboard.md"
$reviewPackage = Join-Path $workspaceRoot "review-packages\latest\review-summary.md"
$readCycleRun = Get-ChildItem -LiteralPath (Join-Path $workspaceRoot "runs") -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "read-cycle*" } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
$writeCycleRun = Get-ChildItem -LiteralPath (Join-Path $workspaceRoot "runs") -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "write-cycle*" } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

$items = New-Object System.Collections.Generic.List[object]

Add-Capability $items "project-open-read" "当前 TIA 工程识别与只读遍历" (Test-PathState $projectModel "READY" "PARTIAL") "读取当前TIA / 浏览打开 / 项目树 / 项目模型 Tab" "doctor, read-cycle, list-plcs, list-blocks, project-model" "PLC_Code\runs, PLC_Code\workbench\context\latest" "Openness readiness, block list, project-model JSON" "首次信任握手、在线状态切换、复杂硬件组态仍可能需要 TIA UI" "把硬件、网络、HMI 设备树加入 object-model。"
Add-Capability $items "lad-read" "LAD/FBD XML 读取、摘要与模板库" (Test-PathState (Join-Path $workspaceRoot "lad-previews") "READY" "READY_NO_LATEST_PREVIEW") "项目树 / LAD预览 / 文件预览" "export-blocks, inspect-lad, summarize-lad, build-lad-catalog" "导出 XML、lad-previews、模板目录" "XML 结构检查和人可读网络摘要" "图形化梯形图编辑的视觉摆放仍以 TIA 为权威" "增加更多 box/network 形态的摘要和差异渲染。"
Add-Capability $items "lad-write" "LAD 结构化写入与克隆编译" (Test-PathState (Join-Path $workspaceRoot "changes") "PARTIAL_READY" "PARTIAL") "PLC改动包 / write-cycle / 审查包" "scaffold-lad-change, write-lad-network, write-lad-batch, patch-lad-network, write-cycle" "LAD JSON、generated.xml、supporting-sources、release package" "validate-lad, clone import, compile, re-export/readback" "不直接编辑 TIA 二进制工程；复杂未知 LAD box 仍需 donor network" "继续扩展自由写入子集，优先覆盖 CALL、比较、定时、计数、运动、通信。"
Add-Capability $items "scl-db-authoring" "SCL、DB、UDT 源码式开发" "READY" "文件预览编辑 / PLC改动包 / Agent队列" "import-sources, plc-change-package, write-cycle support import" "sources、db-contract、import-manifest" "source import, clone compile, project-model readback" "块属性、部分 DB 设置和 know-how protected 内容仍需 TIA/Openness 支持" "加入更强的 DB 版本迁移和 tag contract diff。"
Add-Capability $items "advanced-instructions" "高级指令、库块、通信、PID 与工艺对象路由" (Test-PathState $instructionRoute "READY" "PARTIAL") "指令方案 / 自动流水线 / 验证面板" "plc-instruction-plan" "instruction-route-table, technology-object-plan, safety-risk-assessment" "typed CALL route, clone compile, safety-risk review" "工艺对象创建、轴组态、硬件参数和安全功能仍需 TIA/API 能力确认" "增加 instruction cookbook 和项目接口自动抽取。"
Add-Capability $items "instruction-cookbook" "PLC 指令模板库_InstructionCookbook" (Test-PathState $instructionCookbook "READY" "PARTIAL") "指令库 / 自动流水线 / 验证面板" "plc-instruction-cookbook" "instruction-cookbook.md/json, instruction-risk-checklist.md" "family route matrix plus existing LAD/SCL example anchors" "真实编译仍取决于项目 CPU、库版本、实例 DB 和 Openness 导入结果" "把编译成功的项目案例自动回灌为 validated pattern。"
Add-Capability $items "wincc-visual" "WinCC 参考图/文字到可编辑画面工程包" (Test-PathState $winccPackage "PARTIAL_READY" "PARTIAL") "上传参考图 / WinCC方案 / WinCC插件 / 参考图 Tab" "wincc-plugins, wincc-visual-package, imagegen route, agent-plan" "design brief, screen map, component map, tag contract, style guide" "plugin routing, component-selection matrix, HMI safety review" "实际 screen/object 写入能力取决于 WinCC 类型、SiVArc 许可和 Openness 支持" "补 HMI 对象导入脚本、SiVArc rule scaffold、CWC 包生成器。"
Add-Capability $items "wincc-component-blueprints" "WinCC 组件蓝图_ComponentBlueprints" (Test-PathState $winccComponentBlueprints "READY" "PARTIAL") "组件蓝图 / WinCC方案 / 自动流水线" "wincc-component-blueprints" "component-blueprints.md/json, screen-layout-grid.json, sivarc-rule-blueprints.md, cwc-package-manifest.json" "component-to-tag contract review and HMI safety checklist" "实际导入屏幕对象仍取决于 WinCC 类型、SiVArc/Openness API 和本机许可" "继续补 Openness/SiVArc/CWC 生成器，把蓝图转为可导入对象。"
Add-Capability $items "wincc-engineering-scaffold" "WinCC 工程生成脚手架_WinccEngineeringScaffold" (Test-PathState $winccEngineeringScaffold "PARTIAL_READY" "PARTIAL") "WinCC工程 / 自动流水线 / 验证面板" "wincc-engineering-scaffold" "wincc-engineering-scaffold.md/json, engineering-task-list.csv, tag/alarm maps, SiVArc/CWC checklists" "preflight checklist, tag/alarm mapping, clone validation plan" "真实画面对象写入仍需 WinCC 类型、SiVArc 许可、Openness API 和克隆工程验证" "把 scaffold 的任务逐步升级为真实 HMI tag/alarm/screen/faceplate 生成器。"
Add-Capability $items "agent-client-parity" "本地窗口内置 Agent 对话与执行队列" (Test-PathState $queueJson "PARTIAL_READY" "PARTIAL") "AI 对话 / 任务编排 / 执行队列 / 运行阶段" "agent-chat, agent-plan, agent-queue, queue-stage, queue-run-current" "agent-sessions、agent-queues、logs、evidence" "stage evidence, stdout/stderr capture, review gates" "模型账号、CLI 能力和联网检索仍由外部平台提供" "增加更细的命令面板、文件多选上下文、内置 diff 审批按钮。"
Add-Capability $items "knowledge-retrieval" "官方优先知识检索与社区插件审查" (Test-PathState $knowledgeBrief "READY" "PARTIAL") "知识检索 / 知识库 Tab / 自动流水线" "knowledge-pack -RefreshOnline" "knowledge-brief.md, knowledge-pack.json, agent-retrieval-prompt.md" "source priority, task query list, online metadata timeout fallback" "社区二进制不会自动运行；网页/API 卡顿时必须切换来源" "把成功案例回灌到 cookbook 和 route defaults。"
Add-Capability $items "review-release" "PR 式审查、验证总览与发布边界" (Test-PathState $reviewPackage "READY" "PARTIAL") "审查包 / 总览面板 / 验证面板 / Diff" "review-package, workbench-dashboard, prepare-release, apply-release" "review-summary, artifact-index, import-readiness, dashboard" "hash, diff, readiness, clone compile result" "生产导入和下载必须明确由用户触发" "增加可视化审批流和发布清单签名。"
$simulationStatus = if (Test-Path -LiteralPath $simulationPackage) { "PARTIAL_READY" } elseif ($writeCycleRun) { "PARTIAL_READY" } else { "PARTIAL" }
Add-Capability $items "simulation" "仿真与虚拟调试准备" $simulationStatus "仿真包 / 验证面板 / 自动流水线 / 项目模型" "simulation-package, compile-plc, write-cycle, PLCSIM Advanced hook notes, WinCC Unified GraphQL smoke notes" "simulation-package.md/json, scenario CSV, PLCSIM hook notes, runtime smoke notes" "clone compile, I/O simulation contract, optional PLCSIM/runtime read" "PLCSIM Advanced、硬件仿真和真实下载不是当前自动默认动作" "继续补 PLCSIM API 连接器和可回放 I/O 场景执行器。"

$latestReadCycle = ""
if ($readCycleRun) { $latestReadCycle = $readCycleRun.FullName }
$latestWriteCycle = ""
if ($writeCycleRun) { $latestWriteCycle = $writeCycleRun.FullName }

$json = [pscustomobject]@{
    schemaVersion = 1
    generatedAt = (Get-Date).ToString("o")
    projectRoot = $root
    workflowConfigPath = $WorkflowConfigPath
    taskText = $TaskText
    target = "Approach TIA Portal native editor replacement for daily PLC/WinCC agent-assisted work, while preserving TIA as the authoritative compiler/import/runtime surface."
    readiness = [pscustomobject]@{
        projectModel = (Test-Path -LiteralPath $projectModel)
        agentContext = (Test-Path -LiteralPath $agentContext)
        knowledgePack = (Test-Path -LiteralPath $knowledgeBrief)
        instructionRoute = (Test-Path -LiteralPath $instructionRoute)
        instructionCookbook = (Test-Path -LiteralPath $instructionCookbook)
        winccVisualPackage = (Test-Path -LiteralPath $winccPackage)
        winccComponentBlueprints = (Test-Path -LiteralPath $winccComponentBlueprints)
        winccEngineeringScaffold = (Test-Path -LiteralPath $winccEngineeringScaffold)
        simulationPackage = (Test-Path -LiteralPath $simulationPackage)
        pluginRouting = (Test-Path -LiteralPath $pluginRouting)
        agentQueue = (Test-Path -LiteralPath $queueJson)
        dashboard = (Test-Path -LiteralPath $dashboard)
        reviewPackage = (Test-Path -LiteralPath $reviewPackage)
        latestReadCycle = $latestReadCycle
        latestWriteCycle = $latestWriteCycle
    }
    capabilities = @($items.ToArray())
    safetyBoundary = "The workbench can replace day-to-day source authoring and review, but production import/download and certified safety changes remain explicit gated actions."
}

$jsonPath = Join-Path $OutputDirectory "capability-map.json"
$latestJsonPath = Join-Path $latestDir "capability-map.json"
$json | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
$json | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $latestJsonPath -Encoding UTF8

$md = New-Object System.Text.StringBuilder
[void]$md.AppendLine("# Workbench Capability Map")
[void]$md.AppendLine()
[void]$md.AppendLine("- Project: ``$root``")
[void]$md.AppendLine("- Task: $TaskText")
[void]$md.AppendLine("- Generated: ``$(Get-Date -Format o)``")
[void]$md.AppendLine("- Goal: approach TIA Portal native editor replacement for daily PLC/WinCC Agent work.")
[void]$md.AppendLine()
[void]$md.AppendLine("## Readiness")
[void]$md.AppendLine()
foreach ($prop in $json.readiness.PSObject.Properties) {
    [void]$md.AppendLine("- $($prop.Name): ``$($prop.Value)``")
}
[void]$md.AppendLine()
[void]$md.AppendLine("## Capability Matrix")
[void]$md.AppendLine()
[void]$md.AppendLine("| Capability | Status | Workbench Entry | Backing Command | Validation | Native TIA Still Needed | Next Step |")
[void]$md.AppendLine("| --- | --- | --- | --- | --- | --- | --- |")
foreach ($item in $items) {
    [void]$md.AppendLine("| $($item.name) | $($item.status) | $($item.workbenchEntry) | ``$($item.backingCommand)`` | $($item.validation) | $($item.nativeTiaStillNeeded) | $($item.nextStep) |")
}
[void]$md.AppendLine()
[void]$md.AppendLine("## Practical Boundary")
[void]$md.AppendLine()
[void]$md.AppendLine("The workbench can own project intake, source-like authoring, Agent routing, WinCC visual decomposition, verification evidence and release packages. TIA Portal remains the authoritative importer/compiler/runtime environment, and production changes stay behind explicit release gates.")

$mdPath = Join-Path $OutputDirectory "capability-map.md"
$latestMdPath = Join-Path $latestDir "capability-map.md"
$md.ToString() | Set-Content -LiteralPath $mdPath -Encoding UTF8
$md.ToString() | Set-Content -LiteralPath $latestMdPath -Encoding UTF8

[pscustomobject]@{
    status = "ok"
    outputDirectory = $OutputDirectory
    latestDirectory = $latestDir
    capabilityMap = $mdPath
    capabilityJson = $jsonPath
    capabilityCount = $items.Count
} | ConvertTo-Json -Depth 6
