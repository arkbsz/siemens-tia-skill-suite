param(
    [string]$TargetRoot = (Join-Path $env:USERPROFILE ".codex\skills"),
    [switch]$NoBackup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$packageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceRoot = Join-Path $packageRoot "skills"
$skillNames = @("siemens-tia-plc-dev", "tia-portal-v17", "codex-tia-client", "siemens-wincc-hmi-dev")

if (-not (Test-Path -LiteralPath $sourceRoot)) {
    throw "Missing packaged skills directory: $sourceRoot"
}

New-Item -ItemType Directory -Path $TargetRoot -Force | Out-Null

$backupRoot = Join-Path (Join-Path $env:USERPROFILE ".codex") ("skill-backups\" + (Get-Date -Format "yyyyMMdd_HHmmss"))
if (-not $NoBackup) {
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
}

$results = New-Object System.Collections.Generic.List[object]
foreach ($skillName in $skillNames) {
    $sourcePath = Join-Path $sourceRoot $skillName
    if (-not (Test-Path -LiteralPath $sourcePath)) {
        throw "Missing packaged skill: $sourcePath"
    }

    $targetPath = Join-Path $TargetRoot $skillName
    $backupPath = $null
    if (Test-Path -LiteralPath $targetPath) {
        if ($NoBackup) {
            Remove-Item -LiteralPath $targetPath -Recurse -Force
        }
        else {
            $backupPath = Join-Path $backupRoot $skillName
            Move-Item -LiteralPath $targetPath -Destination $backupPath
        }
    }

    Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Recurse -Force
    $results.Add([pscustomobject]@{
        Skill = $skillName
        Target = $targetPath
        Backup = $backupPath
    })
}

[pscustomobject]@{
    TargetRoot = $TargetRoot
    BackupRoot = if ($NoBackup) { $null } else { $backupRoot }
    Skills = $results
} | ConvertTo-Json -Depth 5
