param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    [string]$WorkflowConfigPath = "",
    [string]$TaskText = "",
    [string]$OutputDirectory = "",
    [switch]$RefreshOnline
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
    param([string]$Path, [int]$Max = 5000)
    if ([string]::IsNullOrWhiteSpace($Path)) { return "" }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return "" }
    $text = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($null -eq $text) { return "" }
    if ($text.Length -gt $Max) { return $text.Substring(0, $Max) + "`r`n... truncated ..." }
    return $text
}

function Test-Any {
    param([string]$Text, [string[]]$Needles)
    foreach ($needle in $Needles) {
        if ($Text.IndexOf($needle, [StringComparison]::OrdinalIgnoreCase) -ge 0) { return $true }
    }
    return $false
}

function Add-Source {
    param(
        $Sources,
        [string]$Id,
        [string]$Title,
        [string]$Url,
        [string]$Kind,
        [string]$Priority,
        [string]$UseFor,
        [string]$Safety
    )
    [void]$Sources.Add([pscustomobject]@{
        id = $Id
        title = $Title
        url = $Url
        kind = $Kind
        priority = $Priority
        useFor = $UseFor
        safety = $Safety
    })
}

function Try-GitHubRepo {
    param([string]$OwnerRepo)
    $uri = "https://api.github.com/repos/$OwnerRepo"
    try {
        return Invoke-RestMethod -Uri $uri -Headers @{ "User-Agent" = "siemens-tia-skill-suite" } -TimeoutSec 12
    }
    catch {
        return $null
    }
}

$root = Resolve-ProjectDirectory -Path $ProjectPath
$workspaceRoot = Join-Path $root "PLC_Code"
if ([string]::IsNullOrWhiteSpace($WorkflowConfigPath)) { $WorkflowConfigPath = Join-Path $workspaceRoot "config\ai-workflow.json" }
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $workspaceRoot ("knowledge\packs\" + (Get-Date -Format "yyyyMMdd-HHmmss"))
}
$latestDir = Join-Path $workspaceRoot "knowledge\packs\latest"
New-Item -ItemType Directory -Path $OutputDirectory, $latestDir -Force | Out-Null

$task = if ([string]::IsNullOrWhiteSpace($TaskText)) { "PLC/WinCC automatic engineering knowledge retrieval" } else { $TaskText }
$projectModel = Join-Path $workspaceRoot "workbench\context\latest\project-model.json"
$agentContext = Join-Path $workspaceRoot "workbench\context\latest\agent-context.md"
$instructionRoute = Join-Path $workspaceRoot "plc\instruction-plans\latest\instruction-route-table.md"
$winccPackage = Join-Path $workspaceRoot "wincc\tasks\latest\implementation-plan.md"

$sources = New-Object System.Collections.Generic.List[object]
Add-Source $sources "openness-import-export" "TIA Portal Openness export/import API" "https://docs.tia.siemens.cloud/r/en-us/v21/tia-portal-openness-api-for-automation-of-engineering-workflows/export/import" "official" "primary" "Project traversal, block export/import, compile-ready engineering automation." "Use on backup/clone first; do not edit binary project storage directly."
Add-Source $sources "openness-block-import" "Openness block import languages" "https://docs.tia.siemens.cloud/r/en-us/v21/tia-portal-openness-api-for-automation-of-engineering-workflows/export/import/importing/exporting-data-of-a-plc-device/blocks/importing-block" "official" "primary" "Import LAD/FBD/GRAPH/SCL/STL block XML through official API." "Clone compile and readback before release."
Add-Source $sources "simatic-sd" "SIMATIC SD text export/import" "https://github.com/siemens/simatic-sd" "official-github" "primary" "Code-like text workflow for V20/V21 LAD/FBD/SCL/DB/UDT where available." "Attributes/settings have restrictions; keep XML as verification fallback."
Add-Source $sources "simatic-sd-docs" "SIMATIC SD block text format docs" "https://docs.tia.siemens.cloud/r/en-us/v21/creating-and-managing-blocks/exporting-and-importing-blocks-in-simatic-sd-format-s7-1200-s7-1500-s7-1200-g2/exporting-and-importing-blocks-in-simatic-sd-format-s7-1200-s7-1500-s7-1200-g2" "official" "primary" "Text-editor and Git workflow for V20/V21 LAD/FBD/SCL blocks, DBs and PLC data types." "Use only when the installed version and block type support it; keep XML/compile readback as fallback."
Add-Source $sources "standard-instructions" "S7-1200/S7-1500 standard instructions" "https://support.industry.siemens.com/cs/document/1214574" "official" "primary" "Instruction semantics, timers, counters, math, conversion, word logic, communication patterns." "Do not infer undocumented behavior; validate in TIA."
Add-Source $sources "programming-guideline" "S7-1200/S7-1500 programming guideline" "https://support.industry.siemens.com/cs/document/81318674" "official" "primary" "Naming, structuring, reusable blocks, diagnostics and maintainability patterns." "Project conventions override generic examples."
Add-Source $sources "openness-snippets" "Siemens official Openness code snippets" "https://github.com/siemens/tia-portal-openness-code-snippets" "official-github" "primary" "Reference snippets for traversing TIA projects, import/export and API usage patterns." "Use source snippets as guidance; bind assemblies from the local licensed TIA installation."
Add-Source $sources "sivarc-openness" "SiVArc Openness generation" "https://docs.tia.siemens.cloud/r/en-us/v21/sivarc-openness/sivarc-generation" "official" "primary" "Rule-based HMI generation from PLC/HMI structures and templates." "Requires installed/licensed option and clone-first generation."
Add-Source $sources "wincc-unified-graphql" "WinCC Unified GraphQL runtime" "https://docs.tia.siemens.cloud/r/en-us/v20/wincc-unified-graphql-rt-unified/introduction-rt-unified" "official" "primary" "Trusted runtime read/subscribe validation for Unified tags and alarms." "Runtime writes/ack/reset require explicit user intent and trusted endpoint."
Add-Source $sources "plcsim-advanced-api" "S7-PLCSIM Advanced API" "https://developer.siemens.com/s7-plcsim-advanced/overview.html" "official" "primary" "Virtual-controller and co-simulation hooks for clone-validated PLC programs." "Use for simulation packages only; production download and runtime writes stay explicit."
Add-Source $sources "cwc-unified" "CWC in WinCC Unified" "https://github.com/tia-portal-applications/CWC-in-WinCC-Unified" "official-github" "primary" "Custom Web Controls for complex Unified widgets that native objects cannot represent cleanly." "Prefer native WinCC controls first; review CWC source and packaging."
Add-Source $sources "tia-openness-mcp" "TIA Portal Openness MCP community adapter" "https://github.com/bulaofen0036-coder/TIA_Portal_Openness_MCP" "community" "review-required" "MCP-style declarative automation ideas for PLC/HMI engineering." "Review source/license; do not run unreviewed binaries on customer projects."
Add-Source $sources "tia-v20-unified-mcp" "TIA V20 Unified MCP community workflow" "https://github.com/Fanqi-dev/tia-v20-unified-mcp" "community" "review-required" "V20/V21 Unified engineering workflow reference." "Treat as experimental and clone-only until locally proven."
Add-Source $sources "tia-utilities" "TiaUtilities" "https://github.com/Parozzz/TiaUtilities" "community" "review-required" "TIA Add-In, XML import/export and code-generation patterns." "Use as source reference; validate writer behavior on clone."
Add-Source $sources "tia-import-export-vsext" "TiaImportExport.VSExt" "https://github.com/cmariusz/TiaImportExport.VSExt" "community" "review-required" "VS Code extension pattern for TIA export/import and viewer workflows, especially V18-V21 and SIMATIC SD." "Review source/license; do not install or execute on production machines without validation."
Add-Source $sources "plcopen-go" "plcopen-go" "https://github.com/suifei/plcopen-go" "community-library" "optional" "PLCopen XML parsing/conversion experiments." "PLCopen interchange is not the same as TIA LAD XML; verify semantics."

$onlineMetadata = @()
if ($RefreshOnline) {
    $repos = @(
        "siemens/simatic-sd",
        "siemens/tia-portal-openness-code-snippets",
        "tia-portal-applications/CWC-in-WinCC-Unified",
        "tia-portal-applications/TableControl",
        "cmariusz/TiaImportExport.VSExt",
        "Parozzz/TiaUtilities",
        "suifei/plcopen-go"
    )
    foreach ($repo in $repos) {
        $metadata = Try-GitHubRepo -OwnerRepo $repo
        if ($metadata) {
            $onlineMetadata += [pscustomobject]@{
                repo = $repo
                fullName = $metadata.full_name
                description = $metadata.description
                pushedAt = $metadata.pushed_at
                stars = $metadata.stargazers_count
                forks = $metadata.forks_count
                license = $(if ($metadata.license) { $metadata.license.spdx_id } else { "" })
                url = $metadata.html_url
            }
        }
        else {
            $onlineMetadata += [pscustomobject]@{
                repo = $repo
                unavailable = $true
                note = "GitHub metadata refresh timed out or failed; keep using cached source anchor."
            }
        }
    }
}

$topics = New-Object System.Collections.Generic.List[string]
if (Test-Any -Text $task -Needles @("lad", "梯形图", "互锁", "报警", "定时", "计数", "顺控")) { [void]$topics.Add("LAD maintenance logic") }
if (Test-Any -Text $task -Needles @("motion", "工艺对象", "伺服", "轴", "回原点", "定位", "MC_")) { [void]$topics.Add("Technology objects and motion") }
if (Test-Any -Text $task -Needles @("modbus", "通信", "通讯", "变频", "驱动", "MB_")) { [void]$topics.Add("Communication and drives") }
if (Test-Any -Text $task -Needles @("pid", "温控", "压力", "模拟量", "scale", "NORM_X", "SCALE_X")) { [void]$topics.Add("Analog, PID and process control") }
if (Test-Any -Text $task -Needles @("wincc", "hmi", "画面", "参考图", "faceplate", "sivarc", "cwc", "趋势")) { [void]$topics.Add("WinCC visual automation") }
if ($topics.Count -eq 0) { [void]$topics.Add("Project read and general automation") }

$queries = @(
    "site:docs.tia.siemens.cloud TIA Portal Openness LAD FBD SCL import export blocks",
    "site:support.industry.siemens.com S7-1200 S7-1500 standard instructions timers counters communication PID",
    "site:docs.tia.siemens.cloud SIMATIC SD LAD FBD SCL DB UDT export import",
    "site:docs.tia.siemens.cloud SiVArc Openness Generate screen rules tag rules",
    "site:developer.siemens.com S7-PLCSIM Advanced API virtual controller co-simulation",
    "site:github.com TIA Portal SIMATIC SD LAD FBD viewer import export",
    "site:github.com tia portal openness mcp wincc unified custom web control"
)

$knowledge = [pscustomobject]@{
    schemaVersion = 1
    generatedAt = (Get-Date).ToString("o")
    projectRoot = $root
    workflowConfigPath = $WorkflowConfigPath
    taskText = $task
    topics = @($topics.ToArray())
    sourcePriority = @("Siemens official docs", "Siemens official GitHub examples", "current project exports", "reviewed community source", "general model knowledge")
    sources = @($sources.ToArray())
    onlineMetadata = @($onlineMetadata)
    retrievalQueries = $queries
    currentProjectContext = [pscustomobject]@{
        projectModel = $(if (Test-Path -LiteralPath $projectModel -PathType Leaf) { $projectModel } else { "" })
        agentContext = $(if (Test-Path -LiteralPath $agentContext -PathType Leaf) { $agentContext } else { "" })
        instructionRoute = $(if (Test-Path -LiteralPath $instructionRoute -PathType Leaf) { $instructionRoute } else { "" })
        winccImplementationPlan = $(if (Test-Path -LiteralPath $winccPackage -PathType Leaf) { $winccPackage } else { "" })
    }
    safety = [pscustomobject]@{
        productionWriteAllowed = $false
        communityBinaryExecution = "disabled until source/license/provenance review and clone validation"
        runtimeWrites = "disabled unless explicitly requested on trusted endpoint"
    }
}

$jsonPath = Join-Path $OutputDirectory "knowledge-pack.json"
$latestJsonPath = Join-Path $latestDir "knowledge-pack.json"
$knowledge | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
$knowledge | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $latestJsonPath -Encoding UTF8

$briefPath = Join-Path $OutputDirectory "knowledge-brief.md"
$latestBriefPath = Join-Path $latestDir "knowledge-brief.md"
$md = New-Object System.Text.StringBuilder
[void]$md.AppendLine("# PLC/WinCC Knowledge Pack")
[void]$md.AppendLine()
[void]$md.AppendLine("- Project: ``$root``")
[void]$md.AppendLine("- Task: $task")
[void]$md.AppendLine("- Generated: ``$(Get-Date -Format o)``")
[void]$md.AppendLine("- Online refresh: ``$($RefreshOnline.IsPresent)``")
[void]$md.AppendLine()
[void]$md.AppendLine("## Retrieval Priority")
[void]$md.AppendLine()
[void]$md.AppendLine("1. Siemens official documents and manuals.")
[void]$md.AppendLine("2. Siemens official GitHub examples and application examples.")
[void]$md.AppendLine("3. Current project exports, object model, read-cycle reports and WinCC packages.")
[void]$md.AppendLine("4. Reviewed community source code and workflow examples.")
[void]$md.AppendLine("5. General model knowledge only after project and source evidence are checked.")
[void]$md.AppendLine()
[void]$md.AppendLine("## Detected Topics")
[void]$md.AppendLine()
foreach ($topic in $topics) { [void]$md.AppendLine("- $topic") }
[void]$md.AppendLine()
[void]$md.AppendLine("## Project Context")
[void]$md.AppendLine()
[void]$md.AppendLine("- Agent context: ``$($knowledge.currentProjectContext.agentContext)``")
[void]$md.AppendLine("- Project model: ``$($knowledge.currentProjectContext.projectModel)``")
[void]$md.AppendLine("- Instruction route: ``$($knowledge.currentProjectContext.instructionRoute)``")
[void]$md.AppendLine("- WinCC implementation plan: ``$($knowledge.currentProjectContext.winccImplementationPlan)``")
[void]$md.AppendLine()
[void]$md.AppendLine("## Recommended Patterns")
[void]$md.AppendLine()
[void]$md.AppendLine("- Use LAD JSON/direct LAD only for maintenance-facing bit logic, interlocks, alarms, timers, counters and simple sequence transitions.")
[void]$md.AppendLine("- Use generic CALL networks for motion, communication, drives, PID/library blocks and technology objects with typed pins.")
[void]$md.AppendLine("- Use SCL for calculations, scaling, strings, arrays, packing, conversion and protocol parsing, then expose the operator-facing layer in LAD/HMI.")
[void]$md.AppendLine("- For V20/V21, prefer SIMATIC SD text workflows when supported; for V16-V19, use Openness XML/SCL and donor-network patterns; keep XML import/compile/readback as the broad verification surface.")
[void]$md.AppendLine("- For WinCC, generate editable native objects first, SiVArc repeated objects second, custom faceplates third, CWC only when native widgets are insufficient.")
[void]$md.AppendLine("- For simulation, prepare static checks, clone compile, readback diff and PLCSIM Advanced hooks before any hardware-facing action.")
[void]$md.AppendLine()
[void]$md.AppendLine("## Sources")
[void]$md.AppendLine()
foreach ($source in $sources) {
    [void]$md.AppendLine("- [$($source.id)] $($source.title): $($source.url)")
    [void]$md.AppendLine("  Use: $($source.useFor)")
    [void]$md.AppendLine("  Safety: $($source.safety)")
}
if ($onlineMetadata.Count -gt 0) {
    [void]$md.AppendLine()
    [void]$md.AppendLine("## Online Metadata")
    [void]$md.AppendLine()
    foreach ($metadata in $onlineMetadata) {
        if ($metadata.unavailable) {
            [void]$md.AppendLine("- $($metadata.repo): unavailable, $($metadata.note)")
        }
        else {
            [void]$md.AppendLine("- $($metadata.fullName): stars=$($metadata.stars), forks=$($metadata.forks), license=$($metadata.license), pushed=$($metadata.pushedAt)")
        }
    }
}
[void]$md.AppendLine()
[void]$md.AppendLine("## Search Queries For Agents")
[void]$md.AppendLine()
foreach ($query in $queries) { [void]$md.AppendLine("- $query") }
[void]$md.AppendLine()
[void]$md.AppendLine("## Guardrails")
[void]$md.AppendLine()
[void]$md.AppendLine("- Do not run unreviewed community binaries.")
[void]$md.AppendLine("- Do not import or download to production from this knowledge package.")
[void]$md.AppendLine("- Treat safety-rated behavior as an engineering review boundary, not an AI-generated feature.")
$md.ToString() | Set-Content -LiteralPath $briefPath -Encoding UTF8
$md.ToString() | Set-Content -LiteralPath $latestBriefPath -Encoding UTF8

$promptPath = Join-Path $OutputDirectory "agent-retrieval-prompt.md"
$latestPromptPath = Join-Path $latestDir "agent-retrieval-prompt.md"
$prompt = New-Object System.Text.StringBuilder
[void]$prompt.AppendLine("# Agent Knowledge Retrieval Prompt")
[void]$prompt.AppendLine()
[void]$prompt.AppendLine("Before editing PLC or WinCC artifacts, read:")
[void]$prompt.AppendLine("- ``$latestBriefPath``")
[void]$prompt.AppendLine("- ``$agentContext``")
[void]$prompt.AppendLine("- ``$instructionRoute``")
[void]$prompt.AppendLine()
[void]$prompt.AppendLine("Task:")
[void]$prompt.AppendLine($task)
[void]$prompt.AppendLine()
[void]$prompt.AppendLine("Use the listed official sources first, then current project artifacts, then reviewed community examples. Convert findings into a concrete LAD/SCL/DB/WinCC plan with verification gates.")
$prompt.ToString() | Set-Content -LiteralPath $promptPath -Encoding UTF8
$prompt.ToString() | Set-Content -LiteralPath $latestPromptPath -Encoding UTF8

[pscustomobject]@{
    status = "ok"
    outputDirectory = $OutputDirectory
    latestDirectory = $latestDir
    knowledgePack = $jsonPath
    knowledgeBrief = $briefPath
    agentPrompt = $promptPath
    sourceCount = $sources.Count
    onlineMetadataCount = @($onlineMetadata).Count
    topics = @($topics.ToArray())
} | ConvertTo-Json -Depth 8
