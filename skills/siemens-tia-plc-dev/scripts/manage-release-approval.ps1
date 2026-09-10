param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    [ValidateSet("refresh", "approve-clone", "approve-production", "reject", "manifest")]
    [string]$Action = "refresh",

    [string]$InputXml = "",

    [string]$PlcName = "PLC_1",

    [string]$TargetProject = "",

    [string]$Note = "",

    [string]$ApprovalPath = ""
)

$ErrorActionPreference = "Stop"

function Resolve-ProjectDirectory {
    param([string]$Path)
    $item = Get-Item -LiteralPath $Path
    if ($item.PSIsContainer) { return $item.FullName }
    return $item.Directory.FullName
}

function Write-JsonFile {
    param(
        [string]$Path,
        [object]$Value
    )
    $parent = Split-Path -Parent $Path
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    $Value | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    return (Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json)
}

function Get-Sha256 {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return "" }
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToUpperInvariant()
}

function Get-ArtifactFingerprint {
    param([object]$ArtifactIndex)
    $rows = New-Object System.Collections.Generic.List[string]
    foreach ($artifact in @($ArtifactIndex)) {
        $rows.Add(("{0}|{1}" -f [string]$artifact.sha256, [string]$artifact.path))
    }
    $canonical = ($rows | Sort-Object) -join "`n"
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($canonical)
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-", "").ToUpperInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Get-LatestWriteReport {
    param([string]$RunsRoot)
    if (-not (Test-Path -LiteralPath $RunsRoot -PathType Container)) { return $null }
    $directory = Get-ChildItem -LiteralPath $RunsRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "write-cycle-*" } |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1
    if (-not $directory) { return $null }
    $reportPath = Join-Path $directory.FullName "workflow-report.json"
    $report = Read-JsonFile -Path $reportPath
    if (-not $report) { return $null }
    return [pscustomobject]@{
        path = $reportPath
        report = $report
    }
}

function Get-ReviewState {
    param([string]$ProjectRoot)
    $latestRoot = Join-Path $ProjectRoot "PLC_Code\review-packages\latest"
    $readinessPath = Join-Path $latestRoot "import-readiness.json"
    $artifactPath = Join-Path $latestRoot "artifact-index.json"
    $readiness = Read-JsonFile -Path $readinessPath
    if (-not $readiness) {
        throw "未找到工作台审查依据，请先执行 review-package：$readinessPath"
    }

    $artifactRows = @()
    if (Test-Path -LiteralPath $artifactPath -PathType Leaf) {
        $artifactRows = @(Read-JsonFile -Path $artifactPath)
    }

    $write = Get-LatestWriteReport -RunsRoot (Join-Path $ProjectRoot "PLC_Code\runs")
    $compileExit = $null
    $writeStatus = "MISSING"
    $writeReportPath = ""
    if ($write) {
        $compileExit = [int]$write.report.CompileExitCode
        $writeStatus = [string]$write.report.Status
        $writeReportPath = $write.path
    }

    $layoutPath = Join-Path $ProjectRoot "PLC_Code\wincc\design-workflow\latest\layout-validation.json"
    $layout = Read-JsonFile -Path $layoutPath
    $layoutStatus = if ($layout) { [string]$layout.status } else { "NOT_AVAILABLE" }
    $fingerprint = if ($readiness.artifactFingerprint) {
        [string]$readiness.artifactFingerprint
    }
    elseif ($artifactRows.Count -gt 0) {
        Get-ArtifactFingerprint -ArtifactIndex $artifactRows
    }
    else {
        ""
    }

    return [pscustomobject]@{
        latestRoot = $latestRoot
        readinessPath = $readinessPath
        artifactIndexPath = $artifactPath
        readiness = $readiness
        artifacts = $artifactRows
        artifactFingerprint = $fingerprint
        compileExitCode = $compileExit
        writeStatus = $writeStatus
        writeReportPath = $writeReportPath
        layoutStatus = $layoutStatus
        layoutPath = $layoutPath
    }
}

function Assert-ProductionReady {
    param([object]$Review)
    if ([string]$Review.readiness.status -ne "ok") {
        throw "审查包状态不是 ok，不能批准生产应用。"
    }
    if ($null -eq $Review.compileExitCode -or [int]$Review.compileExitCode -ne 0) {
        throw "没有成功的克隆编译证据，不能批准生产应用。"
    }
    if ($Review.layoutStatus -eq "REVIEW_REQUIRED") {
        throw "WinCC 布局校验为 REVIEW_REQUIRED，先修复重叠或越界组件。"
    }
    if ([string]::IsNullOrWhiteSpace([string]$Review.artifactFingerprint)) {
        throw "审查包缺少 artifact fingerprint，不能批准生产应用。"
    }
}

$projectRoot = Resolve-ProjectDirectory -Path $ProjectPath
$review = Get-ReviewState -ProjectRoot $projectRoot
if ([string]::IsNullOrWhiteSpace($ApprovalPath)) {
    $ApprovalPath = Join-Path $review.latestRoot "approval.json"
}
if ([string]::IsNullOrWhiteSpace($TargetProject)) {
    $TargetProject = $projectRoot
}
if (-not [string]::IsNullOrWhiteSpace($TargetProject)) {
    try { $TargetProject = (Resolve-ProjectDirectory -Path $TargetProject) } catch { }
}
if ([string]::IsNullOrWhiteSpace($Note)) {
    $Note = "由 Siemens TIA PLC Dev 工作台执行。"
}

$inputFullPath = ""
$inputHash = ""
if (-not [string]::IsNullOrWhiteSpace($InputXml)) {
    if (-not (Test-Path -LiteralPath $InputXml -PathType Leaf)) {
        throw "Input XML not found: $InputXml"
    }
    $inputFullPath = (Get-Item -LiteralPath $InputXml).FullName
    $inputHash = Get-Sha256 -Path $inputFullPath
}

if ($Action -eq "refresh") {
    $approval = [ordered]@{
        schemaVersion = 1
        status = "PENDING"
        approvedFor = "none"
        projectRoot = $projectRoot
        targetProject = $TargetProject
        plcName = $PlcName
        inputXml = $inputFullPath
        inputSha256 = $inputHash
        reviewFingerprint = $review.artifactFingerprint
        artifactCount = @($review.artifacts).Count
        readinessStatus = [string]$review.readiness.status
        cloneCompileExitCode = $review.compileExitCode
        winccLayoutStatus = $review.layoutStatus
        createdAt = (Get-Date).ToString("o")
        approvedAt = $null
        approvedBy = $null
        expiresAt = $null
        note = $Note
        checks = [ordered]@{
            backupRequired = $true
            cloneCompileRequired = $true
            productionWrite = $false
            plcDownload = $false
        }
    }
    Write-JsonFile -Path $ApprovalPath -Value $approval
    [pscustomobject]@{ status = "PENDING"; action = $Action; approvalPath = $ApprovalPath; reviewFingerprint = $review.artifactFingerprint } | ConvertTo-Json -Depth 8
    exit 0
}

if ($Action -eq "approve-production") {
    Assert-ProductionReady -Review $review
}
elseif ($Action -eq "approve-clone") {
    if ([string]$review.readiness.status -ne "ok") {
        throw "审查包状态不是 ok，不能批准克隆导入。"
    }
    if ([string]::IsNullOrWhiteSpace([string]$review.artifactFingerprint)) {
        throw "审查包缺少 artifact fingerprint，不能批准克隆导入。"
    }
}

if ($Action -eq "approve-clone" -or $Action -eq "approve-production") {
    $approvalTtlHours = if ($Action -eq "approve-production") { 24 } else { 72 }
    $approval = [ordered]@{
        schemaVersion = 1
        status = "APPROVED"
        approvedFor = if ($Action -eq "approve-production") { "production" } else { "clone" }
        projectRoot = $projectRoot
        targetProject = $TargetProject
        plcName = $PlcName
        inputXml = $inputFullPath
        inputSha256 = $inputHash
        reviewFingerprint = $review.artifactFingerprint
        artifactCount = @($review.artifacts).Count
        readinessStatus = [string]$review.readiness.status
        cloneCompileExitCode = $review.compileExitCode
        winccLayoutStatus = $review.layoutStatus
        createdAt = (Get-Date).ToString("o")
        approvedAt = (Get-Date).ToString("o")
        approvedBy = [Environment]::UserName
        expiresAt = (Get-Date).AddHours($approvalTtlHours).ToString("o")
        note = $Note
        checks = [ordered]@{
            backupRequired = $true
            cloneCompileRequired = $true
            productionWrite = ($Action -eq "approve-production")
            plcDownload = $false
        }
    }
    Write-JsonFile -Path $ApprovalPath -Value $approval
    [pscustomobject]@{ status = "APPROVED"; action = $Action; approvedFor = $approval.approvedFor; approvalPath = $ApprovalPath; reviewFingerprint = $review.artifactFingerprint; expiresAt = $approval.expiresAt } | ConvertTo-Json -Depth 8
    exit 0
}

if ($Action -eq "reject") {
    $approval = [ordered]@{
        schemaVersion = 1
        status = "REJECTED"
        approvedFor = "none"
        projectRoot = $projectRoot
        targetProject = $TargetProject
        plcName = $PlcName
        inputXml = $inputFullPath
        inputSha256 = $inputHash
        reviewFingerprint = $review.artifactFingerprint
        artifactCount = @($review.artifacts).Count
        readinessStatus = [string]$review.readiness.status
        cloneCompileExitCode = $review.compileExitCode
        winccLayoutStatus = $review.layoutStatus
        createdAt = (Get-Date).ToString("o")
        approvedAt = $null
        approvedBy = [Environment]::UserName
        expiresAt = $null
        note = $Note
        checks = [ordered]@{
            backupRequired = $true
            cloneCompileRequired = $true
            productionWrite = $false
            plcDownload = $false
        }
    }
    Write-JsonFile -Path $ApprovalPath -Value $approval
    [pscustomobject]@{ status = "REJECTED"; action = $Action; approvalPath = $ApprovalPath; reviewFingerprint = $review.artifactFingerprint } | ConvertTo-Json -Depth 8
    exit 0
}

if ($Action -eq "manifest") {
    $approval = Read-JsonFile -Path $ApprovalPath
    $manifestPath = Join-Path $review.latestRoot "release-manifest.json"
    $manifest = [ordered]@{
        schemaVersion = 1
        product = "Siemens TIA PLC Dev Workbench"
        projectRoot = $projectRoot
        generatedAt = (Get-Date).ToString("o")
        targetProject = $TargetProject
        plcName = $PlcName
        inputXml = $inputFullPath
        inputSha256 = $inputHash
        reviewFingerprint = $review.artifactFingerprint
        artifactCount = @($review.artifacts).Count
        readiness = [ordered]@{
            status = [string]$review.readiness.status
            cloneCompileExitCode = $review.compileExitCode
            cloneCompileStatus = $review.writeStatus
            winccLayoutStatus = $review.layoutStatus
        }
        approval = $approval
        productionWrite = $false
        plcDownload = $false
        artifacts = @($review.artifacts)
    }
    Write-JsonFile -Path $manifestPath -Value $manifest
    [pscustomobject]@{ status = "ok"; action = $Action; manifestPath = $manifestPath; approvalPath = $ApprovalPath; reviewFingerprint = $review.artifactFingerprint } | ConvertTo-Json -Depth 10
    exit 0
}

throw "Unsupported approval action: $Action"
