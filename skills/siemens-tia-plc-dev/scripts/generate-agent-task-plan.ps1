param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    [string]$WorkflowConfigPath = "",
    [string]$TaskText = "",
    [string]$Workflow = "auto",
    [string]$AgentId = "auto",
    [string]$ReferenceImagePath = "",
    [string]$OutputDirectory = "",
    [switch]$DebugStage
)

$ErrorActionPreference = "Stop"

function Trace-Stage {
    param([string]$Name)
    if ($DebugStage) { Write-Host ("[agent-plan] " + $Name) }
}

function Resolve-ProjectDirectory {
    param([string]$Path)
    $item = Get-Item -LiteralPath $Path
    if ($item.PSIsContainer) { return $item.FullName }
    return $item.Directory.FullName
}

function Get-ConfigValue {
    param([object]$Config, [string[]]$Path, $Fallback = $null)
    $value = $Config
    foreach ($part in $Path) {
        if ($null -eq $value) { return $Fallback }
        $property = $value.PSObject.Properties[$part]
        if ($null -eq $property) { return $Fallback }
        $value = $property.Value
    }
    if ($null -eq $value) { return $Fallback }
    return $value
}

function Read-ShortText {
    param([string]$Path, [int]$Max = 4000)
    if (-not (Test-Path -LiteralPath $Path)) { return "" }
    $text = Get-Content -LiteralPath $Path -Raw -ErrorAction SilentlyContinue
    if ($null -eq $text) { return "" }
    if ($text.Length -gt $Max) { return $text.Substring(0, $Max) }
    return $text
}

function New-Stage {
    param([string]$Id, [string]$Title, [string]$Agent, [string]$Tools, [string]$Outputs, [string]$Gate, [string]$Notes = "")
    [pscustomobject]@{ id = $Id; title = $Title; agent = $Agent; tools = $Tools; outputs = $Outputs; gate = $Gate; notes = $Notes }
}

function Add-Stage {
    param([System.Collections.Generic.List[object]]$Stages, [object]$Stage)
    [void]$Stages.Add($Stage)
}

function Test-Any {
    param([string]$Text, [string[]]$Needles)
    foreach ($needle in $Needles) {
        if ($Text.IndexOf($needle, [StringComparison]::OrdinalIgnoreCase) -ge 0) { return $true }
    }
    return $false
}

function ConvertTo-JsonString {
    param([string]$Value)
    if ($null -eq $Value) { $Value = "" }
    $Value = $Value.Replace("\", "\\").Replace('"', '\"').Replace("`r", "\r").Replace("`n", "\n").Replace("`t", "\t")
    return '"' + $Value + '"'
}

function Add-JsonProperty {
    param([System.Text.StringBuilder]$Builder, [string]$Name, [string]$Value, [switch]$Comma)
    [void]$Builder.Append("  ")
    [void]$Builder.Append((ConvertTo-JsonString $Name))
    [void]$Builder.Append(": ")
    [void]$Builder.Append((ConvertTo-JsonString $Value))
    if ($Comma) { [void]$Builder.Append(",") }
    [void]$Builder.AppendLine()
}

function Convert-PlanToStableJson {
    param([object]$Plan)
    $json = New-Object System.Text.StringBuilder
    [void]$json.AppendLine("{")
    [void]$json.AppendLine('  "schemaVersion": 1,')
    Add-JsonProperty $json "generatedAt" ([string]$Plan.generatedAt) -Comma
    Add-JsonProperty $json "projectRoot" ([string]$Plan.projectRoot) -Comma
    Add-JsonProperty $json "taskText" ([string]$Plan.taskText) -Comma
    Add-JsonProperty $json "workflowName" ([string]$Plan.workflowName) -Comma
    Add-JsonProperty $json "workflowId" ([string]$Plan.workflowId) -Comma
    Add-JsonProperty $json "agent" ([string]$Plan.agent) -Comma
    Add-JsonProperty $json "platform" ([string]$Plan.platform) -Comma
    Add-JsonProperty $json "configuredPlatform" ([string]$Plan.configuredPlatform) -Comma
    Add-JsonProperty $json "routingMode" ([string]$Plan.routingMode) -Comma
    Add-JsonProperty $json "model" ([string]$Plan.model) -Comma
    Add-JsonProperty $json "languagePreference" ([string]$Plan.languagePreference) -Comma
    Add-JsonProperty $json "tiaSessionMode" ([string]$Plan.tiaSessionMode) -Comma
    Add-JsonProperty $json "plcName" ([string]$Plan.plcName) -Comma
    Add-JsonProperty $json "safetyMode" ([string]$Plan.safetyMode) -Comma
    [void]$json.AppendLine('  "projectFiles": [')
    for ($i = 0; $i -lt $Plan.projectFiles.Count; $i++) {
        [void]$json.Append("    ")
        [void]$json.Append((ConvertTo-JsonString ([string]$Plan.projectFiles[$i])))
        if ($i -lt $Plan.projectFiles.Count - 1) { [void]$json.Append(",") }
        [void]$json.AppendLine()
    }
    [void]$json.AppendLine("  ],")
    [void]$json.AppendLine('  "wincc": {')
    Add-JsonProperty $json "flavor" ([string]$Plan.wincc.flavor) -Comma
    Add-JsonProperty $json "pluginPolicy" ([string]$Plan.wincc.pluginPolicy) -Comma
    Add-JsonProperty $json "imageWorkflow" ([string]$Plan.wincc.imageWorkflow) -Comma
    Add-JsonProperty $json "componentStrategy" ([string]$Plan.wincc.componentStrategy) -Comma
    Add-JsonProperty $json "referenceImage" ([string]$Plan.wincc.referenceImage) -Comma
    Add-JsonProperty $json "pluginRoutingPath" ([string]$Plan.wincc.pluginRoutingPath)
    [void]$json.AppendLine("  },")
    [void]$json.AppendLine('  "stages": [')
    for ($i = 0; $i -lt $Plan.stages.Count; $i++) {
        $stage = $Plan.stages[$i]
        [void]$json.AppendLine("    {")
        [void]$json.AppendLine("      ""id"": " + (ConvertTo-JsonString ([string]$stage.id)) + ",")
        [void]$json.AppendLine("      ""title"": " + (ConvertTo-JsonString ([string]$stage.title)) + ",")
        [void]$json.AppendLine("      ""agent"": " + (ConvertTo-JsonString ([string]$stage.agent)) + ",")
        [void]$json.AppendLine("      ""tools"": " + (ConvertTo-JsonString ([string]$stage.tools)) + ",")
        [void]$json.AppendLine("      ""outputs"": " + (ConvertTo-JsonString ([string]$stage.outputs)) + ",")
        [void]$json.AppendLine("      ""gate"": " + (ConvertTo-JsonString ([string]$stage.gate)) + ",")
        [void]$json.AppendLine("      ""notes"": " + (ConvertTo-JsonString ([string]$stage.notes)))
        [void]$json.Append("    }")
        if ($i -lt $Plan.stages.Count - 1) { [void]$json.Append(",") }
        [void]$json.AppendLine()
    }
    [void]$json.AppendLine("  ],")
    [void]$json.AppendLine('  "capabilityMatrix": [')
    for ($i = 0; $i -lt $Plan.capabilityMatrix.Count; $i++) {
        $capability = $Plan.capabilityMatrix[$i]
        [void]$json.AppendLine("    {")
        [void]$json.AppendLine("      ""area"": " + (ConvertTo-JsonString ([string]$capability.area)) + ",")
        [void]$json.AppendLine("      ""now"": " + (ConvertTo-JsonString ([string]$capability.now)) + ",")
        [void]$json.AppendLine("      ""next"": " + (ConvertTo-JsonString ([string]$capability.next)))
        [void]$json.Append("    }")
        if ($i -lt $Plan.capabilityMatrix.Count - 1) { [void]$json.Append(",") }
        [void]$json.AppendLine()
    }
    [void]$json.AppendLine("  ],")
    Add-JsonProperty $json "latestBlockListExcerpt" ([string]$Plan.latestBlockListExcerpt) -Comma
    Add-JsonProperty $json "pluginRoutingExcerpt" ([string]$Plan.pluginRoutingExcerpt)
    [void]$json.AppendLine("}")
    return $json.ToString()
}

Trace-Stage "resolve-project"
$root = Resolve-ProjectDirectory -Path $ProjectPath
$workspaceRoot = Join-Path $root "PLC_Code"
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) { $OutputDirectory = Join-Path $workspaceRoot "agent-plans" }
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

if ([string]::IsNullOrWhiteSpace($WorkflowConfigPath)) { $WorkflowConfigPath = Join-Path $workspaceRoot "config\ai-workflow.json" }
$config = $null
if (Test-Path -LiteralPath $WorkflowConfigPath) { $config = Get-Content -LiteralPath $WorkflowConfigPath -Raw | ConvertFrom-Json }

Trace-Stage "read-config"
$workflowName = [string](Get-ConfigValue -Config $config -Path @("routing", "workflow") -Fallback $Workflow)
if ([string]::IsNullOrWhiteSpace($workflowName) -or $workflowName -eq "auto") { $workflowName = $Workflow }
$workflowId = $Workflow
$agentProfile = if ($AgentId -and $AgentId -ne "auto") { $AgentId } else { [string](Get-ConfigValue -Config $config -Path @("agent", "profile") -Fallback "auto") }
$model = [string](Get-ConfigValue -Config $config -Path @("routing", "codeModel") -Fallback "inherit")
$routingMode = [string](Get-ConfigValue -Config $config -Path @("platform", "routingMode") -Fallback "auto")
$configuredPlatform = [string](Get-ConfigValue -Config $config -Path @("platform", "selected") -Fallback "auto")
$platform = if ($routingMode -eq "auto") { "auto" } else { $configuredPlatform }
$languagePreference = [string](Get-ConfigValue -Config $config -Path @("routing", "languagePreference") -Fallback "LAD-first")
$safetyMode = [string](Get-ConfigValue -Config $config -Path @("safety", "safetyMode") -Fallback "clone-compile")
$tiaMode = [string](Get-ConfigValue -Config $config -Path @("tia", "sessionMode") -Fallback "attach")
$plcName = [string](Get-ConfigValue -Config $config -Path @("tia", "plcName") -Fallback "PLC_1")
$imageWorkflow = [string](Get-ConfigValue -Config $config -Path @("image", "workflow") -Fallback "auto")
$componentStrategy = [string](Get-ConfigValue -Config $config -Path @("image", "componentStrategy") -Fallback "auto")
$winccFlavor = [string](Get-ConfigValue -Config $config -Path @("wincc", "flavor") -Fallback "auto")
$pluginPolicy = [string](Get-ConfigValue -Config $config -Path @("wincc", "pluginPolicy") -Fallback "auto")
$configuredImage = [string](Get-ConfigValue -Config $config -Path @("image", "referenceImage") -Fallback "")
if ([string]::IsNullOrWhiteSpace($ReferenceImagePath)) { $ReferenceImagePath = $configuredImage }

$normalizedTask = "$TaskText $workflowName $workflowId"
$isWincc = Test-Any -Text $normalizedTask -Needles @("wincc", "hmi", "screen", "visual", "reference", "picture", "image")
$isSafety = Test-Any -Text $normalizedTask -Needles @("safety", "risk", "interlock")
$isAdvancedPlc = Test-Any -Text $normalizedTask -Needles @("advanced-plc", "technology", "motion", "drive", "communication", "modbus", "pid")
$isDb = Test-Any -Text $normalizedTask -Needles @("data-contract", "db", "udt", "tag")
$isLad = Test-Any -Text $normalizedTask -Needles @("plc-lad", "lad", "ladder")
$hasReferenceImage = -not [string]::IsNullOrWhiteSpace($ReferenceImagePath) -and (Test-Path -LiteralPath $ReferenceImagePath)

Trace-Stage "scan-project-files"
$projectFiles = @(Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -match '^\.ap(16|17|18|19|20|21)$' } |
    Sort-Object LastWriteTime -Descending |
    ForEach-Object { $_.FullName })

$latestBlockList = ""
$runsRoot = Join-Path $workspaceRoot "runs"
if (Test-Path -LiteralPath $runsRoot) {
    $latestBlockListPath = Get-ChildItem -LiteralPath $runsRoot -Directory -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        ForEach-Object { Join-Path $_.FullName "reports\block-list.txt" } |
        Where-Object { Test-Path -LiteralPath $_ } |
        Select-Object -First 1
    if ($latestBlockListPath) { $latestBlockList = Read-ShortText -Path $latestBlockListPath -Max 6000 }
}

$pluginRoutingPath = Join-Path $workspaceRoot "wincc\plugin-routing.json"
$pluginRoutingSummary = Read-ShortText -Path $pluginRoutingPath -Max 5000

Trace-Stage "build-stages"
$stages = New-Object System.Collections.Generic.List[object]
Add-Stage $stages (New-Stage "context-read" "Read project context and current code contracts" $agentProfile "project-model, doctor, read-cycle, list-blocks, exported XML/SCL/DB summaries" "PLC_Code/workbench/context/latest/agent-context.md, project-model.json, block catalog, current ai-workflow.json" "No write to production project")
Add-Stage $stages (New-Stage "knowledge-retrieval" "Retrieve official and community knowledge for the exact task" $agentProfile "knowledge-pack, Siemens docs, official Openness snippets, vetted GitHub/community cases, current project exports" "PLC_Code/knowledge/packs/latest/knowledge-brief.md and knowledge-pack.json with source links and implementation route" "Switch source quickly when a site stalls; do not run unreviewed community binaries")

if ($isDb -or $isLad -or $isAdvancedPlc) {
    Add-Stage $stages (New-Stage "plc-contract" "Design PLC contract before logic writes" "data-block" "UDT/DB source review, tag catalog, HMI contract map" "DB/UDT plan with command/status/feedback/interlock/alarm/parameter/diagnostic layers" "Use concise Chinese_English names")
}
if ($isLad) {
    Add-Stage $stages (New-Stage "lad-authoring" "Author maintenance-facing ladder logic" "plc-lad" "LAD JSON writer, donor-network patcher, exported FlgNet templates" "generated LAD XML plus ladder summary" "Use LAD for interlocks, permissives, timers, counters, latches and sequence visibility")
}
if ($isAdvancedPlc) {
    Add-Stage $stages (New-Stage "advanced-plc" "Route advanced Siemens instructions and technology objects" "plc-scl" "generic CALL, SCL source import, technology object mapping, official instruction manuals" "instruction-route table and generated sources/XML" "Motion/communication/drive blocks use typed CALL surfaces; algorithms stay SCL-first")
}
if ($isWincc) {
    Add-Stage $stages (New-Stage "wincc-intake" "Build WinCC visual and tag brief" "wincc" "plugin-routing.json, screen map, PLC/HMI tag contract, reference image if available" "design-brief.md and screen-map.md" "Screens remain editable WinCC objects")
    Add-Stage $stages (New-Stage "visual-reference" "Create or analyze visual reference" "wincc" "imagegen for text-to-image or reference-guided image work" "reference-analysis.md, style-guide.md, optional mockup image" "Image is proof and guide, not a static HMI replacement")
    Add-Stage $stages (New-Stage "component-decomposition" "Split the screen into reusable components" "wincc" "standard controls, faceplates, SiVArc rules, CWC strategy" "component-map.md with object names, tags and safety notes" "Prefer project-local faceplates, then standard controls, then generated faceplates/CWC")
    Add-Stage $stages (New-Stage "wincc-engineering" "Generate or update WinCC engineering objects" "openness" "Openness, SiVArc, reviewed TIA MCP, manual fallback notes" "screens/tags/alarms/faceplates implementation package" "Work on clone or backup; no unreviewed community binary")
}

Add-Stage $stages (New-Stage "simulation-validation" "Run compile, simulation and readback checks" "diagnostics" "write-cycle, compile-plc, PLCSIM/Sim tables when available, runtime GraphQL for Unified validation" "verification report, diffs, failure log" "Do not start a second live TIA import while one is running")
if ($isSafety -or $isWincc -or $isAdvancedPlc) {
    Add-Stage $stages (New-Stage "risk-review" "Perform safety and operator-risk review" "reviewer" "risk checklist, command/feedback/interlock/alarm contract, HMI authority review" "safety-risk-assessment.md" "Flag missing certified safety assumptions instead of inventing safety logic")
}
Add-Stage $stages (New-Stage "release" "Prepare reproducible release package" "auto" "prepare-release, apply-release only after explicit confirmation" "release package, rollback note, change summary" "Production write remains separate from generation and clone validation")

$capabilities = @(
    [pscustomobject]@{ area = "Local workbench"; now = "Agent chat, file upload, model/workflow routing, logs, prompt generation, plan generation, execution queue and current-stage Agent execution with evidence logging"; next = "embedded diff editor, terminal-like command stream, approval checkpoints and first-class compile panels" },
    [pscustomobject]@{ area = "PLC LAD"; now = "contacts, edges, compares, timers, counters, MOVE, SET/RESET, generic CALL, donor-network patching"; next = "more box-shape donors, visual rung preview, reusable device templates" },
    [pscustomobject]@{ area = "Advanced PLC"; now = "route to SCL or CALL for motion, drive, communication, scaling and data handling"; next = "technology object catalog and project-specific compiled examples" },
    [pscustomobject]@{ area = "WinCC"; now = "reference image intake, plugin routing, design/component prompts"; next = "Openness/SiVArc screen writer and CWC packaging adapters" },
    [pscustomobject]@{ area = "Safety"; now = "clone-first and review checklists"; next = "structured risk register and interlock coverage report" }
)

$stageArray = @($stages.ToArray())
$capabilityArray = @($capabilities)

$plan = [pscustomobject]@{
    schemaVersion = 1
    generatedAt = (Get-Date).ToString("o")
    projectRoot = $root
    projectFiles = $projectFiles
    taskText = $TaskText
    workflowName = $workflowName
    workflowId = $workflowId
    agent = $agentProfile
    platform = $platform
    configuredPlatform = $configuredPlatform
    routingMode = $routingMode
    model = $model
    languagePreference = $languagePreference
    tiaSessionMode = $tiaMode
    plcName = $plcName
    safetyMode = $safetyMode
    wincc = [pscustomobject]@{
        flavor = $winccFlavor
        pluginPolicy = $pluginPolicy
        imageWorkflow = $imageWorkflow
        componentStrategy = $componentStrategy
        referenceImage = $(if ($hasReferenceImage) { (Get-Item -LiteralPath $ReferenceImagePath).FullName } else { "" })
        pluginRoutingPath = $(if (Test-Path -LiteralPath $pluginRoutingPath) { $pluginRoutingPath } else { "" })
    }
    stages = $stageArray
    capabilityMatrix = $capabilityArray
    latestBlockListExcerpt = $latestBlockList
    pluginRoutingExcerpt = $pluginRoutingSummary
}

Trace-Stage "write-json"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$jsonPath = Join-Path $OutputDirectory "$stamp-agent-task-plan.json"
$mdPath = Join-Path $OutputDirectory "$stamp-agent-task-plan.md"
$latestJson = Join-Path $OutputDirectory "latest-plan.json"
$latestMd = Join-Path $OutputDirectory "latest-plan.md"

$jsonText = Convert-PlanToStableJson -Plan $plan
$jsonText | Set-Content -LiteralPath $jsonPath -Encoding UTF8
$jsonText | Set-Content -LiteralPath $latestJson -Encoding UTF8

Trace-Stage "write-markdown"
$md = New-Object System.Text.StringBuilder
[void]$md.AppendLine("# Siemens TIA Agent Workbench Plan")
[void]$md.AppendLine()
[void]$md.AppendLine("- Project: ``$root``")
[void]$md.AppendLine("- Workflow: ``$workflowName`` / ``$workflowId``")
[void]$md.AppendLine("- Agent: ``$agentProfile``")
[void]$md.AppendLine("- Platform: ``$platform`` ($routingMode; configured preference: ``$configuredPlatform``)")
[void]$md.AppendLine("- Model: ``$model``")
[void]$md.AppendLine("- Language preference: ``$languagePreference``")
[void]$md.AppendLine("- Safety mode: ``$safetyMode``")
[void]$md.AppendLine("- Reference image: ``" + $(if ($hasReferenceImage) { (Get-Item -LiteralPath $ReferenceImagePath).FullName } else { "none" }) + "``")
[void]$md.AppendLine()
[void]$md.AppendLine("## User Task")
[void]$md.AppendLine()
[void]$md.AppendLine($TaskText)
[void]$md.AppendLine()
[void]$md.AppendLine("## Execution Stages")
[void]$md.AppendLine()
foreach ($stage in $stages) {
    [void]$md.AppendLine("### " + $stage.id + " - " + $stage.title)
    [void]$md.AppendLine("- Agent: ``" + $stage.agent + "``")
    [void]$md.AppendLine("- Tools: " + $stage.tools)
    [void]$md.AppendLine("- Outputs: " + $stage.outputs)
    [void]$md.AppendLine("- Gate: " + $stage.gate)
    if (-not [string]::IsNullOrWhiteSpace($stage.notes)) { [void]$md.AppendLine("- Notes: " + $stage.notes) }
    [void]$md.AppendLine()
}
[void]$md.AppendLine("## Capability Matrix")
[void]$md.AppendLine()
foreach ($capability in $capabilities) {
    [void]$md.AppendLine("- " + $capability.area + ": now = " + $capability.now + "; next = " + $capability.next)
}
[void]$md.AppendLine()
[void]$md.AppendLine("## Required Safety Discipline")
[void]$md.AppendLine()
[void]$md.AppendLine("- Back up first; clone before write; compile and read back before release.")
[void]$md.AppendLine("- Keep production writes separate from Agent generation.")
[void]$md.AppendLine("- Runtime HMI writes, alarm acknowledge, recipe write, homing and reset need explicit user intent.")
[void]$md.AppendLine("- Certified safety functions must be implemented and validated in the proper safety engineering workflow.")
[void]$md.AppendLine()
[void]$md.AppendLine("## Source Priority")
[void]$md.AppendLine()
[void]$md.AppendLine("- Siemens official docs and support manuals.")
[void]$md.AppendLine("- Siemens official Openness snippets.")
[void]$md.AppendLine("- Vetted community examples and open-source tools.")
[void]$md.AppendLine("- Current project exports, block summaries, DB/UDT contracts and compile logs.")

$md.ToString() | Set-Content -LiteralPath $mdPath -Encoding UTF8
$md.ToString() | Set-Content -LiteralPath $latestMd -Encoding UTF8

Trace-Stage "done"
$status = New-Object System.Text.StringBuilder
[void]$status.AppendLine("{")
[void]$status.AppendLine('  "status": "ok",')
[void]$status.AppendLine('  "jsonPath": ' + (ConvertTo-JsonString $jsonPath) + ',')
[void]$status.AppendLine('  "markdownPath": ' + (ConvertTo-JsonString $mdPath) + ',')
[void]$status.AppendLine('  "latestJson": ' + (ConvertTo-JsonString $latestJson) + ',')
[void]$status.AppendLine('  "latestMarkdown": ' + (ConvertTo-JsonString $latestMd))
[void]$status.AppendLine("}")
$status.ToString()
