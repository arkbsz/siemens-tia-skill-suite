param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    [string]$WorkflowConfigPath = "",

    [string]$TaskText = "",

    [string]$ReferenceImagePath = "",

    [string]$OutputPath = "",

    [switch]$RefreshCatalog
)

$ErrorActionPreference = "Stop"

# Keep this script encoded as UTF-8 with BOM so Windows PowerShell 5.1 parses
# the Chinese workflow option values consistently.

function Resolve-ProjectDirectory {
    param([string]$Path)
    $item = Get-Item -LiteralPath $Path
    if ($item.PSIsContainer) { return $item.FullName }
    return $item.Directory.FullName
}

function Find-FirstExistingPath {
    param([string[]]$Candidates)
    foreach ($candidate in $Candidates) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate)) {
            return (Get-Item -LiteralPath $candidate).FullName
        }
    }
    return ""
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

function Get-TiaVersion {
    param([string]$ProjectDirectory)
    $projectFile = Get-ChildItem -LiteralPath $ProjectDirectory -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -match '^\.ap(16|17|18|19|20|21)$' } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($projectFile -and $projectFile.Extension -match '^\.ap(?<version>\d+)$') {
        return [int]$Matches.version
    }

    $installed = Get-ChildItem -LiteralPath "C:\Program Files\Siemens\Automation" -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^Portal V(?<version>\d+)$' } |
        Sort-Object { [int]([regex]::Match($_.Name, '\d+').Value) } -Descending |
        Select-Object -First 1
    if ($installed) { return [int]([regex]::Match($installed.Name, '\d+').Value) }
    return 0
}

function Get-OnlineMetadata {
    param([string]$Url)
    if ($Url -notmatch '^https://github\.com/(?<owner>[^/]+)/(?<repo>[^/#]+)') { return $null }
    $api = "https://api.github.com/repos/$($Matches.owner)/$($Matches.repo)"
    try {
        $headers = @{ "User-Agent" = "Siemens-TIA-Skill-Suite"; "Accept" = "application/vnd.github+json" }
        $repo = Invoke-RestMethod -Uri $api -Headers $headers -TimeoutSec 8
        return [pscustomobject]@{
            FullName = $repo.full_name
            Stars = [int]$repo.stargazers_count
            Archived = [bool]$repo.archived
            PushedAt = $repo.pushed_at
            License = if ($repo.license) { $repo.license.spdx_id } else { "Unknown" }
            Url = $repo.html_url
        }
    }
    catch {
        return [pscustomobject]@{ Url = $Url; Error = $_.Exception.Message }
    }
}

$projectDirectory = Resolve-ProjectDirectory -Path $ProjectPath
$workspaceRoot = Join-Path $projectDirectory "PLC_Code"
$winccRoot = Join-Path $workspaceRoot "wincc"
New-Item -ItemType Directory -Path $winccRoot -Force | Out-Null

if ([string]::IsNullOrWhiteSpace($WorkflowConfigPath)) {
    $WorkflowConfigPath = Join-Path $workspaceRoot "config\ai-workflow.json"
}
$config = $null
if (Test-Path -LiteralPath $WorkflowConfigPath) {
    $WorkflowConfigPath = (Get-Item -LiteralPath $WorkflowConfigPath).FullName
    $config = Get-Content -LiteralPath $WorkflowConfigPath -Raw | ConvertFrom-Json
}

$catalogPath = Join-Path (Split-Path -Parent $PSScriptRoot) "references\wincc-plugin-catalog.json"
$catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json
$tiaVersion = Get-TiaVersion -ProjectDirectory $projectDirectory
$flavor = [string](Get-ConfigValue -Config $config -Path @("wincc", "flavor") -Fallback "自动检测")
$pluginPolicy = [string](Get-ConfigValue -Config $config -Path @("wincc", "pluginPolicy") -Fallback "自动选择")
$configuredReferenceImage = [string](Get-ConfigValue -Config $config -Path @("image", "referenceImage") -Fallback "")
if ([string]::IsNullOrWhiteSpace($ReferenceImagePath)) { $ReferenceImagePath = $configuredReferenceImage }

$externalRoot = Join-Path $env:USERPROFILE ".codex\external\wincc-plugins"
$imagegenSkillPath = Find-FirstExistingPath -Candidates @(
    (Join-Path $env:USERPROFILE ".codex\skills\.system\imagegen\SKILL.md"),
    (Join-Path $env:USERPROFILE ".codex\skills\imagegen\SKILL.md")
)
$plcSkillRoot = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "siemens-tia-plc-dev"
$opennessScriptPath = Find-FirstExistingPath -Candidates @(
    (Join-Path $plcSkillRoot "scripts\invoke-siemens-plc-dev.ps1"),
    (Join-Path $env:USERPROFILE ".codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1")
)
$publicApiRoot = if ($tiaVersion -gt 0) { "C:\Program Files\Siemens\Automation\Portal V$tiaVersion\PublicAPI\V$tiaVersion" } else { "" }
$hmiApiPath = Find-FirstExistingPath -Candidates @(
    (Join-Path $publicApiRoot "Siemens.Engineering.HmiUnified.dll"),
    (Join-Path $publicApiRoot "Siemens.Engineering.Hmi.dll")
)
$sivarcApiPath = ""
if (-not [string]::IsNullOrWhiteSpace($publicApiRoot) -and (Test-Path -LiteralPath $publicApiRoot)) {
    $sivarcCandidate = Get-ChildItem -LiteralPath $publicApiRoot -File -Filter "*SiVArc*.dll" -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
    if ($sivarcCandidate) { $sivarcApiPath = [string]$sivarcCandidate }
}

$tiaMcpPath = Find-FirstExistingPath -Candidates @(
    [string](Get-ConfigValue -Config $config -Path @("wincc", "tiaMcpPath") -Fallback ""),
    $env:TIA_MCP_SERVER_PATH,
    (Join-Path $externalRoot "TIA_Portal_Openness_MCP\tools\tiaportal-mcp\src\TiaMcpServer\bin\Release\net48\TiaMcpServer.exe"),
    (Join-Path $externalRoot "TIA_Portal_Openness_MCP\tools\tiaportal-mcp\src\TiaMcpServer\bin-v20\Release\net48\TiaMcpServer.exe")
)
$showScriptsPath = Find-FirstExistingPath -Candidates @(
    [string](Get-ConfigValue -Config $config -Path @("wincc", "showScriptsPath") -Fallback ""),
    $env:TIA_SHOW_SCRIPTS_PATH,
    (Join-Path $externalRoot "TIA-Add-In-ShowScripts\ShowScripts.addin"),
    (Join-Path $externalRoot "TIA-Add-In-ShowScripts\ShowScripts.exe")
)
$runtimeMcpPath = Find-FirstExistingPath -Candidates @(
    [string](Get-ConfigValue -Config $config -Path @("wincc", "runtimeMcpPath") -Fallback ""),
    $env:WINCCUA_MCP_SERVER_PATH,
    (Join-Path $externalRoot "winccua-mcp-server\index.js")
)
$graphqlUrl = [string](Get-ConfigValue -Config $config -Path @("wincc", "graphqlUrl") -Fallback $env:GRAPHQL_URL)

$onlineMetadata = @()
if ($RefreshCatalog -and $pluginPolicy -ne "禁用插件") {
    foreach ($plugin in $catalog.plugins) {
        if ([string]$plugin.url -like "https://github.com/*") {
            $onlineMetadata += Get-OnlineMetadata -Url ([string]$plugin.url)
        }
    }
    $onlineMetadata | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $winccRoot "plugin-catalog.online.json") -Encoding UTF8
}

$hasReferenceImage = -not [string]::IsNullOrWhiteSpace($ReferenceImagePath) -and (Test-Path -LiteralPath $ReferenceImagePath)
$wantsVisual = $hasReferenceImage -or $TaskText -match '画面|界面|参考图|截图|布局|配色|HMI|WinCC'
$wantsRuntime = $TaskText -match '运行时|GraphQL|报警验证|标签值|趋势数据|runtime'
$isUnified = $flavor -match 'Unified' -or $TaskText -match 'Unified'

$detectedPlugins = @(
    [pscustomobject]@{ Id = "codex-imagegen"; Ready = [bool]$imagegenSkillPath; Path = $imagegenSkillPath; Compatible = $true; Role = "visual-concept" },
    [pscustomobject]@{ Id = "siemens-openness"; Ready = [bool]($opennessScriptPath -and $hmiApiPath); Path = $opennessScriptPath; ApiPath = $hmiApiPath; Compatible = ($tiaVersion -ge 16 -and $tiaVersion -le 21); Role = "engineering" },
    [pscustomobject]@{ Id = "sivarc-openness"; Ready = [bool]$sivarcApiPath; Path = $sivarcApiPath; Compatible = [bool]$sivarcApiPath; Role = "rule-generation" },
    [pscustomobject]@{ Id = "tia-openness-mcp"; Ready = [bool]$tiaMcpPath; Path = $tiaMcpPath; Compatible = ($tiaVersion -ge 20 -and $tiaVersion -le 21); Role = "engineering" },
    [pscustomobject]@{ Id = "show-scripts-addin"; Ready = [bool]$showScriptsPath; Path = $showScriptsPath; Compatible = ($tiaVersion -ge 17); Role = "screen-script-audit" },
    [pscustomobject]@{ Id = "winccua-mcp-server"; Ready = [bool]($runtimeMcpPath -and $graphqlUrl); Path = $runtimeMcpPath; Endpoint = $graphqlUrl; Compatible = $isUnified; Role = "runtime-validation" }
)

$invocationPlan = New-Object System.Collections.Generic.List[object]
if ($wantsVisual -and $imagegenSkillPath) {
    $invocationPlan.Add([pscustomobject]@{
        Stage = "visual-concept"
        Adapter = "codex-imagegen"
        Ready = $true
        Invocation = "Use `$imagegen with the uploaded reference image or design brief, then convert the result into WinCC-native components."
        Reason = if ($hasReferenceImage) { "Reference image is available." } else { "The task requests visual screen design." }
    })
}

$engineeringAdapter = "siemens-openness"
$engineeringReady = [bool]($opennessScriptPath -and $hmiApiPath)
if ($pluginPolicy -ne "仅官方/本机" -and $tiaVersion -ge 20 -and $tiaVersion -le 21 -and $tiaMcpPath) {
    $engineeringAdapter = "tia-openness-mcp"
    $engineeringReady = $true
}
$invocationPlan.Add([pscustomobject]@{
    Stage = "engineering"
    Adapter = $engineeringAdapter
    Ready = $engineeringReady
    Invocation = if ($engineeringAdapter -eq "tia-openness-mcp") { "Call the configured TIA MCP HMI screen/tag/event tools on a cloned project." } else { "Call the local Siemens Openness workflow on a cloned project; use manual import only for unsupported screen objects." }
    Reason = if ($tiaVersion -lt 20) { "TIA V$tiaVersion uses the local version-compatible Openness route." } else { "The best compatible installed engineering adapter was selected." }
})

if ($showScriptsPath -and $tiaVersion -ge 17) {
    $invocationPlan.Add([pscustomobject]@{ Stage = "screen-script-audit"; Adapter = "show-scripts-addin"; Ready = $true; Invocation = "Export Unified screen JavaScript for AI/code review."; Reason = "The Add-In is installed and compatible." })
}
if ($wantsRuntime) {
    $invocationPlan.Add([pscustomobject]@{ Stage = "runtime-validation"; Adapter = "winccua-mcp-server"; Ready = [bool]($runtimeMcpPath -and $graphqlUrl -and $isUnified); Invocation = "Browse tags and alarms through the configured Unified GraphQL MCP server; keep write and acknowledge operations disabled unless explicitly requested."; Reason = "The task includes runtime validation." })
}

$installSuggestions = @()
if ($tiaVersion -ge 17 -and -not $showScriptsPath) {
    $installSuggestions += [pscustomobject]@{ Id = "show-scripts-addin"; Url = "https://github.com/tia-portal-applications/TIA-Add-In-ShowScripts"; Why = "Exports screen JavaScript for review; useful on V17+ Unified projects."; Action = "Review source, build against the matching TIA Add-In SDK, then set wincc.showScriptsPath." }
}
if ($tiaVersion -ge 20 -and $tiaVersion -le 21 -and -not $tiaMcpPath -and $pluginPolicy -ne "仅官方/本机") {
    $installSuggestions += [pscustomobject]@{ Id = "tia-openness-mcp"; Url = "https://github.com/bulaofen0036-coder/TIA_Portal_Openness_MCP"; Why = "Adds declarative Unified HMI generation for V20/V21."; Action = "Review source and release provenance, install in the external plugin directory, then set wincc.tiaMcpPath." }
}
if ($isUnified -and -not $runtimeMcpPath) {
    $installSuggestions += [pscustomobject]@{ Id = "winccua-mcp-server"; Url = "https://github.com/vogler75/winccua-mcp-server"; Why = "Adds GraphQL runtime tag/alarm inspection."; Action = "Review and install only on a trusted engineering network; set wincc.runtimeMcpPath and wincc.graphqlUrl." }
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $winccRoot "plugin-routing.json"
}
$report = [pscustomobject]@{
    GeneratedAt = (Get-Date).ToString("o")
    ProjectPath = $projectDirectory
    TiaVersion = if ($tiaVersion) { "V$tiaVersion" } else { "Unknown" }
    WinccFlavor = $flavor
    PluginPolicy = $pluginPolicy
    WorkflowConfigPath = $WorkflowConfigPath
    ReferenceImage = if ($hasReferenceImage) { (Get-Item -LiteralPath $ReferenceImagePath).FullName } else { "" }
    CatalogPath = $catalogPath
    OnlineMetadata = $onlineMetadata
    DetectedPlugins = $detectedPlugins
    InvocationPlan = $invocationPlan
    InstallSuggestions = $installSuggestions
    Guardrails = @(
        "Do not run downloaded prebuilt executables before source/provenance review.",
        "Use a cloned TIA project for first engineering writes.",
        "Do not use runtime tag write or alarm acknowledge tools unless the user explicitly requests that operation.",
        "Never disable TLS validation for a production WinCC Unified endpoint."
    )
}

$report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
$report | ConvertTo-Json -Depth 10
