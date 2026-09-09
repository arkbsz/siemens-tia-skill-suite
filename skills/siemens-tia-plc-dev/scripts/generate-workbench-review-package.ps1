param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    [string]$WorkflowConfigPath = "",
    [string]$OutputDirectory = ""
)

$ErrorActionPreference = "Stop"

function Resolve-ProjectDirectory {
    param([string]$Path)
    $item = Get-Item -LiteralPath $Path
    if ($item.PSIsContainer) { return $item.FullName }
    return $item.Directory.FullName
}

function Write-Doc {
    param([string]$Path, [string]$Content)
    Set-Content -LiteralPath $Path -Value $Content -Encoding UTF8
}

function Read-ShortText {
    param([string]$Path, [int]$Max = 6000)
    if (-not (Test-Path -LiteralPath $Path)) { return "" }
    $text = Get-Content -LiteralPath $Path -Raw -ErrorAction SilentlyContinue
    if ($null -eq $text) { return "" }
    if ($text.Length -gt $Max) { return $text.Substring(0, $Max) + "`n... truncated ..." }
    return $text
}

function ConvertTo-JsonString {
    param([string]$Value)
    if ($null -eq $Value) { $Value = "" }
    $Value = $Value.Replace("\", "\\").Replace('"', '\"').Replace("`r", "\r").Replace("`n", "\n").Replace("`t", "\t")
    return '"' + $Value + '"'
}

function Add-ArtifactRows {
    param([System.Collections.Generic.List[object]]$Rows, [string]$Root, [string]$Area)
    if (-not (Test-Path -LiteralPath $Root)) { return }
    foreach ($file in Get-ChildItem -LiteralPath $Root -File -Recurse -ErrorAction SilentlyContinue) {
        $hash = Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName
        $Rows.Add([pscustomobject]@{
            area = $Area
            path = $file.FullName
            relativePath = $file.FullName.Substring($Root.Length).TrimStart('\')
            bytes = $file.Length
            lastWriteTime = $file.LastWriteTime.ToString("o")
            sha256 = $hash.Hash
        })
    }
}

$root = Resolve-ProjectDirectory -Path $ProjectPath
$workspaceRoot = Join-Path $root "PLC_Code"
if ([string]::IsNullOrWhiteSpace($WorkflowConfigPath)) { $WorkflowConfigPath = Join-Path $workspaceRoot "config\ai-workflow.json" }

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) { $OutputDirectory = Join-Path $workspaceRoot "review-packages\$stamp-workbench-review" }
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $OutputDirectory "logs") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $OutputDirectory "evidence") -Force | Out-Null

$latestDir = Join-Path $workspaceRoot "review-packages\latest"
New-Item -ItemType Directory -Path $latestDir -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $latestDir "logs") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $latestDir "evidence") -Force | Out-Null

$latestPlan = Join-Path $workspaceRoot "agent-plans\latest-plan.md"
$latestQueue = Join-Path $workspaceRoot "agent-queues\latest\queue.md"
$latestPlcPackage = Join-Path $workspaceRoot "changes\latest-plc-change-package"
$latestWinccPackage = Join-Path $workspaceRoot "wincc\tasks\latest"
$latestPluginRoute = Join-Path $workspaceRoot "wincc\plugin-routing.json"

$artifacts = New-Object System.Collections.Generic.List[object]
Add-ArtifactRows -Rows $artifacts -Root $latestPlcPackage -Area "PLC_CHANGE_PACKAGE"
Add-ArtifactRows -Rows $artifacts -Root $latestWinccPackage -Area "WINCC_VISUAL_PACKAGE"
$singleFiles = @(
    @{ area = "AGENT_PLAN"; path = $latestPlan },
    @{ area = "AGENT_QUEUE"; path = $latestQueue },
    @{ area = "WINCC_PLUGIN_ROUTE"; path = $latestPluginRoute },
    @{ area = "WORKFLOW_CONFIG"; path = $WorkflowConfigPath }
)
foreach ($entry in $singleFiles) {
    if (Test-Path -LiteralPath $entry.path) {
        $file = Get-Item -LiteralPath $entry.path
        $hash = Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName
        $artifacts.Add([pscustomobject]@{
            area = $entry.area
            path = $file.FullName
            relativePath = $file.Name
            bytes = $file.Length
            lastWriteTime = $file.LastWriteTime.ToString("o")
            sha256 = $hash.Hash
        })
    }
}

$artifactJson = Join-Path $OutputDirectory "artifact-index.json"
$latestArtifactJson = Join-Path $latestDir "artifact-index.json"
$artifacts | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $artifactJson -Encoding UTF8
$artifacts | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $latestArtifactJson -Encoding UTF8

$csvPath = Join-Path $OutputDirectory "artifact-index.csv"
$latestCsvPath = Join-Path $latestDir "artifact-index.csv"
$artifacts | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8
$artifacts | Export-Csv -LiteralPath $latestCsvPath -NoTypeInformation -Encoding UTF8

$gitDiff = ""
$gitRoot = ""
try {
    $gitRoot = (& git -C $root rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitRoot)) {
        $gitDiff = (& git -C $gitRoot diff -- . 2>$null) -join [Environment]::NewLine
    }
}
catch {
    $gitDiff = ""
}

$patchPath = Join-Path $OutputDirectory "git-diff.patch"
$latestPatchPath = Join-Path $latestDir "git-diff.patch"
if ([string]::IsNullOrWhiteSpace($gitDiff)) { $gitDiff = "# No git diff available for project root $root" }
Write-Doc -Path $patchPath -Content $gitDiff
Write-Doc -Path $latestPatchPath -Content $gitDiff

$summary = New-Object System.Text.StringBuilder
[void]$summary.AppendLine("# Workbench Review Package")
[void]$summary.AppendLine()
[void]$summary.AppendLine("- Project: ``$root``")
[void]$summary.AppendLine("- Created: ``$(Get-Date -Format o)``")
[void]$summary.AppendLine("- Workflow config: ``$WorkflowConfigPath``")
[void]$summary.AppendLine("- Artifact count: ``$($artifacts.Count)``")
[void]$summary.AppendLine("- Release allowed: ``false``")
[void]$summary.AppendLine()
[void]$summary.AppendLine("## Review Inputs")
[void]$summary.AppendLine()
[void]$summary.AppendLine("- Agent plan: ``$latestPlan``")
[void]$summary.AppendLine("- Agent queue: ``$latestQueue``")
[void]$summary.AppendLine("- PLC change package: ``$latestPlcPackage``")
[void]$summary.AppendLine("- WinCC visual package: ``$latestWinccPackage``")
[void]$summary.AppendLine("- Plugin route: ``$latestPluginRoute``")
[void]$summary.AppendLine()
[void]$summary.AppendLine("## Current Queue Excerpt")
[void]$summary.AppendLine()
[void]$summary.AppendLine('```markdown')
[void]$summary.AppendLine((Read-ShortText -Path $latestQueue -Max 5000))
[void]$summary.AppendLine('```')
[void]$summary.AppendLine()
[void]$summary.AppendLine("## Current WinCC Package Excerpt")
[void]$summary.AppendLine()
[void]$summary.AppendLine('```markdown')
[void]$summary.AppendLine((Read-ShortText -Path (Join-Path $latestWinccPackage "component-selection-matrix.md") -Max 4000))
[void]$summary.AppendLine('```')
[void]$summary.AppendLine()
[void]$summary.AppendLine("## Review Gates")
[void]$summary.AppendLine()
[void]$summary.AppendLine("- Confirm affected PLC blocks, DB/UDT contracts, HMI tags and screen objects.")
[void]$summary.AppendLine("- Confirm commands, feedback, status, interlocks, alarms, parameters and diagnostics are not mixed.")
[void]$summary.AppendLine("- Confirm LAD/XML/SCL/DB sources are generated from exported or documented surfaces, not from TIA binary storage.")
[void]$summary.AppendLine("- Confirm clone compile or equivalent offline validation before release.")
[void]$summary.AppendLine("- Confirm safety assumptions are documented and certified safety logic remains outside AI-only generation.")

$summaryPath = Join-Path $OutputDirectory "review-summary.md"
$latestSummaryPath = Join-Path $latestDir "review-summary.md"
Write-Doc -Path $summaryPath -Content $summary.ToString()
Write-Doc -Path $latestSummaryPath -Content $summary.ToString()

$readiness = New-Object System.Text.StringBuilder
[void]$readiness.AppendLine("{")
[void]$readiness.AppendLine('  "status": "ok",')
[void]$readiness.AppendLine('  "projectRoot": ' + (ConvertTo-JsonString $root) + ',')
[void]$readiness.AppendLine('  "artifactCount": ' + $artifacts.Count + ',')
[void]$readiness.AppendLine('  "hasAgentPlan": ' + ((Test-Path -LiteralPath $latestPlan).ToString().ToLowerInvariant()) + ',')
[void]$readiness.AppendLine('  "hasAgentQueue": ' + ((Test-Path -LiteralPath $latestQueue).ToString().ToLowerInvariant()) + ',')
[void]$readiness.AppendLine('  "hasPlcChangePackage": ' + ((Test-Path -LiteralPath $latestPlcPackage).ToString().ToLowerInvariant()) + ',')
[void]$readiness.AppendLine('  "hasWinccVisualPackage": ' + ((Test-Path -LiteralPath $latestWinccPackage).ToString().ToLowerInvariant()) + ',')
[void]$readiness.AppendLine('  "releaseAllowed": false')
[void]$readiness.AppendLine("}")

Write-Doc -Path (Join-Path $OutputDirectory "import-readiness.json") -Content $readiness.ToString()
Write-Doc -Path (Join-Path $latestDir "import-readiness.json") -Content $readiness.ToString()

@"
{
  "status": "ok",
  "outputDirectory": "$($OutputDirectory.Replace('\', '\\'))",
  "latestDirectory": "$($latestDir.Replace('\', '\\'))",
  "summary": "$($summaryPath.Replace('\', '\\'))"
}
"@
