param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    [string]$WorkspaceName = "PLC_Code"
)

$ErrorActionPreference = "Stop"

$item = Get-Item -LiteralPath $ProjectPath
$projectDir = if ($item.PSIsContainer) { $item.FullName } else { $item.Directory.FullName }
$workspace = Join-Path $projectDir $WorkspaceName

$folders = @(
    "blocks",
    "ladders",
    "types",
    "tags",
    "alarms",
    "imports",
    "exports",
    "reports",
    "templates"
)

New-Item -ItemType Directory -Path $workspace -Force | Out-Null
foreach ($folder in $folders) {
    New-Item -ItemType Directory -Path (Join-Path $workspace $folder) -Force | Out-Null
}

foreach ($subfolder in @(
    (Join-Path $workspace "templates\lad"),
    (Join-Path $workspace "templates\scl")
)) {
    New-Item -ItemType Directory -Path $subfolder -Force | Out-Null
}

$manifestPath = Join-Path $workspace "manifest.json"
if (-not (Test-Path -LiteralPath $manifestPath)) {
    $manifest = [ordered]@{
        projectPath = $projectDir
        workspace = $workspace
        tiaVersion = "V17"
        workflow = "export-edit-check-import-compile"
        importOrder = @(
            "types",
            "blocks",
            "tags",
            "alarms"
        )
        notes = @(
            "Do not edit TIA internal binary project files directly.",
            "Export from TIA before broad refactors.",
            "Import into a backup project before production use."
        )
    }
    $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
}

$readmePath = Join-Path $workspace "README.md"
if (-not (Test-Path -LiteralPath $readmePath)) {
    @'
# PLC Code Workspace

This folder is the text workspace for Siemens TIA Portal PLC work.

Use it for exported XML, generated SCL, import manifests, and reports.

Recommended loop:

1. Back up the TIA project.
2. Export from TIA into `exports`.
3. Edit or generate files under `blocks`, `ladders`, `types`, and `tags`.
4. Run checks.
5. Import through Openness or MCP.
6. Compile in TIA.
'@ | Set-Content -LiteralPath $readmePath -Encoding UTF8
}

$ladReadmePath = Join-Path (Join-Path $workspace "ladders") "README.md"
if (-not (Test-Path -LiteralPath $ladReadmePath)) {
    @'
# LAD Workspace

Use this folder for exported and edited LAD/FBD XML or SIMATIC SD document exports.

Workflow:

1. Export an existing LAD block from TIA with Openness or MCP.
2. Keep the original export in `..\exports`.
3. Copy the block XML/document here before editing.
4. Inspect with `inspect-lad-xml.ps1`.
5. Validate with `validate-lad-xml.ps1`.
6. Import into a backup project and compile in TIA.

Do not hand-write a full LAD graph from scratch unless using an exported TIA block as a template.
'@ | Set-Content -LiteralPath $ladReadmePath -Encoding UTF8
}

[pscustomobject]@{
    Project = $projectDir
    Workspace = $workspace
    Manifest = $manifestPath
} | Format-List
