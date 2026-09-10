param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    [string]$HmiDeviceName = "",

    [string]$ImplementationPath = "",

    [string]$ReleaseApprovalPath = "",

    [switch]$ApplyToClone
)

$ErrorActionPreference = "Stop"

function Resolve-ProjectDirectory {
    param([string]$Path)
    $item = Get-Item -LiteralPath $Path
    if ($item.PSIsContainer) { return $item.FullName }
    return $item.Directory.FullName
}

function Invoke-Captured {
    param(
        [string]$ScriptPath,
        [string[]]$Arguments,
        [string]$LogPath
    )

    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $text = ($output | Out-String).TrimEnd()
    $text | Set-Content -LiteralPath $LogPath -Encoding UTF8
    [pscustomobject]@{
        ExitCode = $exitCode
        Output = $text
        LogPath = $LogPath
    }
}

function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    return (Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json)
}

function Assert-CloneApproval {
    param(
        [string]$Path,
        [string]$ProjectRoot
    )
    if ([string]::IsNullOrWhiteSpace($Path)) {
        $Path = Join-Path $ProjectRoot "PLC_Code\review-packages\latest\approval.json"
    }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "未找到克隆导入审批记录，请先在工作台生成审查包并批准克隆导入：$Path"
    }
    $approval = Read-JsonFile -Path $Path
    if ([string]$approval.status -ne "APPROVED" -or @("clone", "production") -notcontains [string]$approval.approvedFor) {
        throw "审批记录不是 APPROVED/clone，WinCC 克隆导入已阻断。"
    }
    $readiness = Read-JsonFile -Path (Join-Path $ProjectRoot "PLC_Code\review-packages\latest\import-readiness.json")
    if (-not $readiness -or [string]$approval.reviewFingerprint -ne [string]$readiness.artifactFingerprint) {
        throw "审查包指纹已变化或缺失，请重新生成审查包并批准克隆导入。"
    }
    return $approval
}

if (-not $ApplyToClone) {
    throw "Clone-only guard: pass -ApplyToClone after reviewing the implementation package."
}

$projectItem = Get-Item -LiteralPath $ProjectPath
$resolvedProject = $projectItem.FullName
$projectRoot = Resolve-ProjectDirectory -Path $resolvedProject
if ([string]::IsNullOrWhiteSpace($ReleaseApprovalPath)) {
    $ReleaseApprovalPath = Join-Path $projectRoot "PLC_Code\review-packages\latest\approval.json"
}
Assert-CloneApproval -Path $ReleaseApprovalPath -ProjectRoot $projectRoot | Out-Null
if ([string]::IsNullOrWhiteSpace($ImplementationPath)) {
    $ImplementationPath = Join-Path $projectRoot "PLC_Code\wincc\openness-implementation\latest"
}
if (Test-Path -LiteralPath $ImplementationPath -PathType Leaf) {
    $ImplementationPath = Split-Path -Parent $ImplementationPath
}
if (-not (Test-Path -LiteralPath $ImplementationPath -PathType Container)) {
    throw "WinCC implementation package not found: $ImplementationPath"
}

$runName = "wincc-implementation-" + (Get-Date -Format "yyyyMMdd-HHmmss")
$runRoot = Join-Path $projectRoot "PLC_Code\wincc\openness-implementation\$runName"
$logRoot = Join-Path $runRoot "logs"
$readbackRoot = Join-Path $runRoot "clone-readback"
New-Item -ItemType Directory -Path $logRoot, $readbackRoot -Force | Out-Null

$invokeScript = Join-Path $PSScriptRoot "invoke-siemens-plc-dev.ps1"
$hmiListResult = Invoke-Captured -ScriptPath $invokeScript -Arguments @(
    "list-hmi", "--project", $resolvedProject
) -LogPath (Join-Path $logRoot "preflight-list-hmi.log")
if ($hmiListResult.ExitCode -ne 0) {
    throw "WinCC preflight failed with exit code $($hmiListResult.ExitCode). See $($hmiListResult.LogPath)"
}
$hmiCount = 0
if ($hmiListResult.Output -match "SUMMARY\s+HmiTargets\s+(\d+)") {
    $hmiCount = [int]$Matches[1]
}
if ($hmiCount -eq 0) {
    $blockedReport = [pscustomobject]@{
        status = "blocked-no-hmi-target"
        productionWrite = $false
        sourceProject = $resolvedProject
        implementationPath = $ImplementationPath
        preflightLog = $hmiListResult.LogPath
        completedAt = (Get-Date).ToString("o")
        notes = @(
            "No engineering HMI target was exposed by TIA Portal Openness.",
            "The source project was not cloned and no write was attempted.",
            "Add a WinCC target to the project or use read-only PLC workflows first."
        )
    }
    $blockedPath = Join-Path $runRoot "implementation-run.json"
    $blockedReport | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $blockedPath -Encoding UTF8
    @(
        "# WinCC implementation blocked",
        "",
        "- Status: ``blocked-no-hmi-target``",
        "- Source project: ``$resolvedProject``",
        "- Preflight log: ``$($hmiListResult.LogPath)``",
        "",
        "No HMI target was found. No clone or write was attempted."
    ) -join [Environment]::NewLine | Set-Content -LiteralPath (Join-Path $runRoot "README.md") -Encoding UTF8
    Write-Output ("BLOCKED`tNo HMI target was found. Report: {0}" -f $blockedPath)
    exit 2
}

$cloneRoot = Join-Path $projectRoot "PLC_Code\wincc\clones"
$cloneName = "wincc_clone_" + (Get-Date -Format "yyyyMMdd-HHmmss")
$cloneResult = Invoke-Captured -ScriptPath $invokeScript -Arguments @(
    "clone-project", "-ProjectPath", $resolvedProject, "-CloneRoot", $cloneRoot, "-CloneName", $cloneName
) -LogPath (Join-Path $logRoot "clone.log")
if ($cloneResult.ExitCode -ne 0) {
    throw "Clone creation failed with exit code $($cloneResult.ExitCode). See $($cloneResult.LogPath)"
}

$cloneInfo = $cloneResult.Output | ConvertFrom-Json
$clonePath = [string]$cloneInfo.ClonePath
$cloneProjectFile = @($cloneInfo.ProjectFiles | Where-Object { $_ -match '\.ap(1[6-9]|2[0-1])$' } | Select-Object -First 1)
if ([string]::IsNullOrWhiteSpace($clonePath) -or -not (Test-Path -LiteralPath $clonePath)) {
    throw "Clone path was not returned or does not exist: $clonePath"
}
if ($cloneProjectFile.Count -eq 0) {
    $cloneProjectFile = Get-ChildItem -LiteralPath $clonePath -File -Force | Where-Object { $_.Extension -match '^\.ap(1[6-9]|2[0-1])$' } | Select-Object -ExpandProperty FullName -First 1
}
if ([string]::IsNullOrWhiteSpace([string]$cloneProjectFile)) {
    throw "No TIA project file found in clone: $clonePath"
}

$tagCsv = Join-Path $ImplementationPath "hmi-tag-import-map.csv"
$alarmCsv = Join-Path $ImplementationPath "alarm-import-map.csv"
$screenCsv = Join-Path $ImplementationPath "screen-object-map.csv"
if (-not (Test-Path -LiteralPath $tagCsv -PathType Leaf)) {
    $tagCsv = Join-Path $projectRoot "PLC_Code\wincc\engineering-scaffold\latest\hmi-tag-import-map.csv"
}
if (-not (Test-Path -LiteralPath $alarmCsv -PathType Leaf)) {
    $alarmCsv = Join-Path $projectRoot "PLC_Code\wincc\engineering-scaffold\latest\alarm-import-map.csv"
}
if (-not (Test-Path -LiteralPath $screenCsv -PathType Leaf)) {
    throw "Screen implementation map not found: $screenCsv"
}

$applyArgs = @(
    "apply-hmi-manifest",
    "--project", [string]$cloneProjectFile,
    "--tag-csv", $tagCsv,
    "--alarm-csv", $alarmCsv,
    "--screen-csv", $screenCsv,
    "--apply"
)
if (-not [string]::IsNullOrWhiteSpace($HmiDeviceName)) {
    $applyArgs += @("--hmi", $HmiDeviceName)
}
$applyResult = Invoke-Captured -ScriptPath $invokeScript -Arguments $applyArgs -LogPath (Join-Path $logRoot "apply-hmi-manifest.log")
if ($applyResult.ExitCode -ne 0) {
    throw "WinCC clone implementation failed with exit code $($applyResult.ExitCode). See $($applyResult.LogPath)"
}

$readbackArgs = @(
    "read-hmi", "--project", [string]$cloneProjectFile, "--output", $readbackRoot
)
if (-not [string]::IsNullOrWhiteSpace($HmiDeviceName)) {
    $readbackArgs += @("--hmi", $HmiDeviceName)
}
$readbackResult = Invoke-Captured -ScriptPath $invokeScript -Arguments $readbackArgs -LogPath (Join-Path $logRoot "clone-readback.log")
if ($readbackResult.ExitCode -ne 0) {
    throw "WinCC clone readback failed with exit code $($readbackResult.ExitCode). See $($readbackResult.LogPath)"
}

$report = [pscustomobject]@{
    status = "ok"
    productionWrite = $false
    sourceProject = $resolvedProject
    cloneProject = $cloneProjectFile
    cloneDirectory = $clonePath
    implementationPath = $ImplementationPath
    releaseApprovalPath = $ReleaseApprovalPath
    hmiDeviceName = $HmiDeviceName
    tagCsv = $tagCsv
    alarmCsv = $alarmCsv
    screenCsv = $screenCsv
    applyLog = $applyResult.LogPath
    readbackLog = $readbackResult.LogPath
    readbackReport = Join-Path $readbackRoot "wincc-readback.json"
    completedAt = (Get-Date).ToString("o")
    notes = @(
        "The generated objects were applied to a cloned TIA project only.",
        "No PLC download and no production project write were performed.",
        "Readback is the acceptance evidence; inspect apply-hmi-manifest.log for created/updated counts and warnings."
    )
}
$reportPath = Join-Path $runRoot "implementation-run.json"
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $reportPath -Encoding UTF8

$readme = @(
    "# WinCC clone implementation run",
    "",
    "- Source project: ``$resolvedProject``",
    "- Clone project: ``$cloneProjectFile``",
    "- Production write: ``false``",
    "- Apply log: ``$($applyResult.LogPath)``",
    "- Readback report: ``$($report.readbackReport)``",
    "",
    "This run is clone-only. Review the readback report before any separately approved release action."
) -join [Environment]::NewLine
$readme | Set-Content -LiteralPath (Join-Path $runRoot "README.md") -Encoding UTF8

[pscustomobject]@{
    status = "ok"
    runRoot = $runRoot
    cloneProject = $cloneProjectFile
    implementationRun = $reportPath
    readback = $report.readbackReport
    productionWrite = $false
} | ConvertTo-Json -Depth 6
