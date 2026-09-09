param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath
)

$ErrorActionPreference = "Stop"

$skillsRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $PSScriptRoot "resolve-bridge-skill.ps1")

$bridge = Resolve-TiaBridgeSkill -SkillsRoot $skillsRoot
$catalog = Resolve-TiaBridgeScript -SkillPath $bridge.SkillPath -Candidates @(
    "scripts\build-lad-template-catalog.ps1"
)
$templateIndex = Resolve-TiaBridgeScript -SkillPath $bridge.SkillPath -Candidates @(
    "scripts\build-lad-template-index.ps1"
)

foreach ($path in @($catalog, $templateIndex)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing dependency script: $path"
    }
}

$projectItem = Get-Item -LiteralPath $ProjectPath
$projectDir = if ($projectItem.PSIsContainer) { $projectItem.FullName } else { $projectItem.Directory.FullName }
$workspacePath = Join-Path $projectDir "PLC_Code"
$laddersPath = Join-Path $workspacePath "ladders"
$templatesPath = Join-Path $workspacePath "templates\lad"
$reportsPath = Join-Path $workspacePath "reports"

$catalogPath = $null
$indexPath = $null

if (Test-Path -LiteralPath $laddersPath) {
    $catalogPath = Join-Path $reportsPath "lad-template-catalog.md"
    & $catalog -Path $laddersPath -OutputPath $catalogPath | Out-Null
}

if (Test-Path -LiteralPath $templatesPath) {
    $templateFiles = @(Get-ChildItem -LiteralPath $templatesPath -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*.template.json" })
    if ($templateFiles.Count -gt 0) {
        $indexPath = Join-Path $templatesPath "template-index.md"
        & $templateIndex -Path $templatesPath -OutputPath $indexPath | Out-Null
    }
}

[pscustomobject]@{
    ProjectPath = $projectDir
    WorkspacePath = $workspacePath
    CatalogPath = $catalogPath
    TemplateIndexPath = $indexPath
} | ConvertTo-Json -Depth 4
