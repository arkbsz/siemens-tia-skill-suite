param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath
)

$ErrorActionPreference = "Stop"

$skillsRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $PSScriptRoot "resolve-bridge-skill.ps1")

$bridge = Resolve-TiaBridgeSkill -SkillsRoot $skillsRoot
$probe = Resolve-TiaBridgeScript -SkillPath $bridge.SkillPath -Candidates @(
    "scripts\probe-tia-portal.ps1",
    "scripts\probe-tia-v17.ps1"
)
$init = Resolve-TiaBridgeScript -SkillPath $bridge.SkillPath -Candidates @(
    "scripts\init-plc-code-workspace.ps1"
)
$catalog = Resolve-TiaBridgeScript -SkillPath $bridge.SkillPath -Candidates @(
    "scripts\build-lad-template-catalog.ps1"
)
$templateIndex = Resolve-TiaBridgeScript -SkillPath $bridge.SkillPath -Candidates @(
    "scripts\build-lad-template-index.ps1"
)

foreach ($path in @($probe, $init, $catalog, $templateIndex)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing dependency script: $path"
    }
}

$probeResult = & $probe -ProjectPath $ProjectPath | ConvertFrom-Json
$workspaceResult = & $init -ProjectPath $ProjectPath | Out-String

$projectItem = Get-Item -LiteralPath $ProjectPath
$projectDir = if ($projectItem.PSIsContainer) { $projectItem.FullName } else { $projectItem.Directory.FullName }
$workspacePath = Join-Path $projectDir "PLC_Code"
$laddersPath = Join-Path $workspacePath "ladders"
$templatesPath = Join-Path $workspacePath "templates\lad"
$reportsPath = Join-Path $workspacePath "reports"

$catalogPath = $null
$indexPath = $null

if (Test-Path -LiteralPath $laddersPath) {
    $xmlCount = @(Get-ChildItem -LiteralPath $laddersPath -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -ieq ".xml" }).Count
    if ($xmlCount -gt 0) {
        $catalogPath = Join-Path $reportsPath "lad-template-catalog.md"
        & $catalog -Path $laddersPath -OutputPath $catalogPath | Out-Null
    }
}

if (Test-Path -LiteralPath $templatesPath) {
    $templateCount = @(Get-ChildItem -LiteralPath $templatesPath -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*.template.json" }).Count
    if ($templateCount -gt 0) {
        $indexPath = Join-Path $templatesPath "template-index.md"
        & $templateIndex -Path $templatesPath -OutputPath $indexPath | Out-Null
    }
}

[pscustomobject]@{
    ProjectPath = $projectDir
    WorkspacePath = $workspacePath
    Probe = $probeResult
    CatalogPath = $catalogPath
    TemplateIndexPath = $indexPath
} | ConvertTo-Json -Depth 6
