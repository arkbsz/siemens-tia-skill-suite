param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    [string]$BackupRoot
)

$ErrorActionPreference = "Stop"

function Resolve-ProjectDirectory {
    param([string]$InputPath)

    $item = Get-Item -LiteralPath $InputPath
    if ($item.PSIsContainer) {
        return $item
    }

    return $item.Directory
}

function Get-ProjectName {
    param(
        [System.IO.DirectoryInfo]$ProjectDir,
        [string]$OriginalPath
    )

    $item = Get-Item -LiteralPath $OriginalPath
    if (-not $item.PSIsContainer -and $item.Extension) {
        return [System.IO.Path]::GetFileNameWithoutExtension($item.Name)
    }

    return $ProjectDir.Name
}

function ConvertTo-SafeFileName {
    param([string]$Name)

    $safe = [System.Text.RegularExpressions.Regex]::Replace($Name, '[^A-Za-z0-9._-]+', '_')
    $safe = $safe.Trim('_')
    if ([string]::IsNullOrWhiteSpace($safe)) {
        return "tia_project"
    }

    return $safe
}

$projectDir = Resolve-ProjectDirectory -InputPath $ProjectPath
$projectName = Get-ProjectName -ProjectDir $projectDir -OriginalPath $ProjectPath
$safeProjectName = ConvertTo-SafeFileName -Name $projectName
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

if (-not $BackupRoot) {
    $parent = Split-Path -Parent $projectDir.FullName
    $BackupRoot = Join-Path $parent "_backup"
}

New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null

$zipPath = Join-Path $BackupRoot ($safeProjectName + "_full_backup_" + $timestamp + ".zip")
$snapshotPath = Join-Path $BackupRoot ($safeProjectName + "_snapshot_" + $timestamp)

try {
    Compress-Archive -LiteralPath $projectDir.FullName -DestinationPath $zipPath -CompressionLevel Optimal
    [pscustomobject]@{
        Mode = "zip"
        Project = $projectDir.FullName
        Backup = $zipPath
        Timestamp = $timestamp
    } | Format-List
    exit 0
}
catch {
    New-Item -ItemType Directory -Path $snapshotPath -Force | Out-Null
    $null = robocopy $projectDir.FullName $snapshotPath /E /R:1 /W:1 /NFL /NDL /NJH /NJS /NP
    [pscustomobject]@{
        Mode = "snapshot"
        Project = $projectDir.FullName
        Backup = $snapshotPath
        Timestamp = $timestamp
        Note = "Zip backup failed, usually because TIA files were locked. A directory snapshot was created instead."
    } | Format-List
    exit 0
}
