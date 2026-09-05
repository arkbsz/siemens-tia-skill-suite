param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    [string]$CloneRoot,

    [string]$CloneName
)

$ErrorActionPreference = "Stop"

$projectItem = Get-Item -LiteralPath $ProjectPath
$projectDir = if ($projectItem.PSIsContainer) { $projectItem } else { $projectItem.Directory }

if (-not $CloneRoot) {
    $CloneRoot = Join-Path $projectDir.Parent.FullName "_backup"
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$baseName = if ($CloneName) {
    $CloneName
} else {
    "codex_clone_{0}" -f $timestamp
}

$safeName = [System.Text.RegularExpressions.Regex]::Replace($baseName, '[^A-Za-z0-9._-]+', '_').Trim('_')
if ([string]::IsNullOrWhiteSpace($safeName)) {
    $safeName = "codex_clone_{0}" -f $timestamp
}

$clonePath = Join-Path $CloneRoot $safeName
if (Test-Path -LiteralPath $clonePath) {
    throw "Clone destination already exists: $clonePath"
}

New-Item -ItemType Directory -Path $CloneRoot -Force | Out-Null
New-Item -ItemType Directory -Path $clonePath -Force | Out-Null

$null = robocopy $projectDir.FullName $clonePath /E /R:1 /W:1 /NFL /NDL /NJH /NJS /NP
$robocopyCode = $LASTEXITCODE
if ($robocopyCode -ge 8) {
    throw "Project clone failed with robocopy exit code $robocopyCode"
}

$projectFiles = @(
    Get-ChildItem -LiteralPath $clonePath -File -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -match '^\.ap(1[6-9]|2[0-1])$' } |
        Select-Object -ExpandProperty FullName
)

[pscustomobject]@{
    SourceProject = $projectDir.FullName
    ClonePath = $clonePath
    Ap17Files = @($projectFiles | Where-Object { $_ -match '\.ap17$' })
    ProjectFiles = $projectFiles
    Timestamp = $timestamp
} | ConvertTo-Json -Depth 4
