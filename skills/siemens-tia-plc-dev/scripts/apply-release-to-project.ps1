param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    [Parameter(Mandatory = $true)]
    [string]$InputXml,

    [Parameter(Mandatory = $true)]
    [string]$PlcName,

    [string]$BlockName,

    [string]$ReleaseLabel,

    [string]$VerifyOutputRoot,

    [string]$ReleaseApprovalPath = "",

    [switch]$SkipBackup,

    [switch]$DryRunOnly
)

$ErrorActionPreference = "Stop"

function Get-BlockInfoFromXml {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $xml = New-Object System.Xml.XmlDocument
    $xml.PreserveWhitespace = $true
    $xml.Load($Path)

    $blockNode = @($xml.DocumentElement.ChildNodes | Where-Object { $_.LocalName -like "SW.Blocks.*" } | Select-Object -First 1)[0]
    if (-not $blockNode) {
        throw "Unable to determine block info from XML: $Path"
    }

    $nameNode = $blockNode.SelectSingleNode("./*[local-name()='AttributeList']/*[local-name()='Name']")
    $langNode = $blockNode.SelectSingleNode("./*[local-name()='AttributeList']/*[local-name()='ProgrammingLanguage']")

    [pscustomobject]@{
        BlockName = if ($nameNode) { $nameNode.InnerText.Trim() } else { [System.IO.Path]::GetFileNameWithoutExtension($Path) }
        ProgrammingLanguage = if ($langNode) { $langNode.InnerText.Trim() } else { "" }
    }
}

function Invoke-PowerShellStep {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [int[]]$AllowedExitCodes = @(0)
    )

    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @Arguments 2>&1
    $exitCode = $LASTEXITCODE

    if ($AllowedExitCodes -notcontains $exitCode) {
        $message = if ($output) { ($output | Out-String) } else { "" }
        throw "Step failed for $ScriptPath with exit code $exitCode.`n$message"
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Output = @($output)
    }
}

function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    return (Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json)
}

function Get-Sha256 {
    param([string]$Path)
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToUpperInvariant()
}

function Assert-ReleaseApproval {
    param(
        [string]$Path,
        [string]$ProjectRoot,
        [string]$XmlPath
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "未找到生产应用审批记录，生产写入已阻断：$Path"
    }
    $approval = Read-JsonFile -Path $Path
    if ([string]$approval.status -ne "APPROVED" -or [string]$approval.approvedFor -ne "production") {
        throw "审批记录不是 APPROVED/production，生产写入已阻断。"
    }
    if ([string]$approval.projectRoot -ne $ProjectRoot -or [string]$approval.targetProject -ne $ProjectRoot) {
        throw "审批目标工程与当前工程不一致，生产写入已阻断。"
    }
    if ($approval.expiresAt) {
        $expires = [DateTime]::Parse([string]$approval.expiresAt)
        if ($expires.ToUniversalTime() -le (Get-Date).ToUniversalTime()) {
            throw "审批记录已过期，生产写入已阻断。"
        }
    }
    $actualHash = Get-Sha256 -Path $XmlPath
    if ([string]$approval.inputXml -ne $XmlPath -or [string]$approval.inputSha256 -ne $actualHash) {
        throw "审批记录中的输入 XML 或 SHA256 与当前输入不一致，生产写入已阻断。"
    }
    $readinessPath = Join-Path $ProjectRoot "PLC_Code\review-packages\latest\import-readiness.json"
    $readiness = Read-JsonFile -Path $readinessPath
    if (-not $readiness -or [string]$approval.reviewFingerprint -ne [string]$readiness.artifactFingerprint) {
        throw "审查包指纹已变化或缺失，请重新生成审查包并审批。"
    }
    return $approval
}

if (-not (Test-Path -LiteralPath $InputXml)) {
    throw "Input XML not found: $InputXml"
}

$invokeScript = Join-Path $PSScriptRoot "invoke-siemens-plc-dev.ps1"
foreach ($path in @($invokeScript)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing dependency script: $path"
    }
}

$projectItem = Get-Item -LiteralPath $ProjectPath
$projectDir = if ($projectItem.PSIsContainer) { $projectItem.FullName } else { $projectItem.Directory.FullName }
$workspacePath = Join-Path $projectDir "PLC_Code"

if ([string]::IsNullOrWhiteSpace($ReleaseApprovalPath)) {
    $ReleaseApprovalPath = Join-Path $workspacePath "review-packages\latest\approval.json"
}
if (-not $DryRunOnly) {
    $releaseApproval = Assert-ReleaseApproval -Path $ReleaseApprovalPath -ProjectRoot $projectDir -XmlPath (Get-Item -LiteralPath $InputXml).FullName
}

$blockInfo = Get-BlockInfoFromXml -Path $InputXml
$resolvedBlockName = if ($BlockName) { $BlockName } else { $blockInfo.BlockName }
$label = if ($ReleaseLabel) { $ReleaseLabel } else { [System.IO.Path]::GetFileNameWithoutExtension($InputXml) }
$safeLabel = (($label -replace '[\\/:*?"<>| ]+', "-").Trim("-"))
if ([string]::IsNullOrWhiteSpace($safeLabel)) {
    $safeLabel = "plc-release"
}

if (-not $VerifyOutputRoot) {
    $VerifyOutputRoot = Join-Path $workspacePath "verification"
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$verifyDir = Join-Path $VerifyOutputRoot ($safeLabel + "_" + $timestamp)
$exportDir = Join-Path $verifyDir "post-apply-export"
$reportPath = Join-Path $verifyDir "apply-report.json"
$summaryPath = Join-Path $verifyDir ($safeLabel + ".post-apply.lad.md")

New-Item -ItemType Directory -Path $verifyDir -Force | Out-Null
New-Item -ItemType Directory -Path $exportDir -Force | Out-Null

$backupOutput = $null
if (-not $SkipBackup) {
    $backupStep = Invoke-PowerShellStep -ScriptPath $invokeScript -Arguments @(
        "backup-project",
        "-ProjectPath", $ProjectPath
    )
    $backupOutput = ($backupStep.Output -join [Environment]::NewLine).Trim()
}

$dryRunStep = Invoke-PowerShellStep -ScriptPath $invokeScript -Arguments @(
    "import-blocks",
    "--project", $ProjectPath,
    "--input", $InputXml,
    "--plc", $PlcName
)

if ($DryRunOnly) {
    $report = [ordered]@{
        ProjectPath = $projectDir
        InputXml = (Get-Item -LiteralPath $InputXml).FullName
        PlcName = $PlcName
        BlockName = $resolvedBlockName
        VerificationDirectory = $verifyDir
        ReleaseApprovalPath = $ReleaseApprovalPath
        BackupOutput = $backupOutput
        DryRunOutput = ($dryRunStep.Output -join [Environment]::NewLine).Trim()
        DryRunOnly = $true
    } | ConvertTo-Json -Depth 5

    Set-Content -LiteralPath $reportPath -Value $report -Encoding UTF8
    [pscustomobject]@{
        VerificationDirectory = $verifyDir
        ReportPath = $reportPath
        DryRunOnly = $true
    } | ConvertTo-Json -Depth 4
    exit 0
}

$applyStep = Invoke-PowerShellStep -ScriptPath $invokeScript -Arguments @(
    "import-blocks",
    "--project", $ProjectPath,
    "--input", $InputXml,
    "--plc", $PlcName,
    "--apply"
)

$compileStep = Invoke-PowerShellStep -ScriptPath $invokeScript -Arguments @(
    "compile-plc",
    "--project", $ProjectPath,
    "--plc", $PlcName,
    "--save"
) -AllowedExitCodes @(0, 1)

$exportStep = Invoke-PowerShellStep -ScriptPath $invokeScript -Arguments @(
    "export-blocks",
    "--project", $ProjectPath,
    "--plc", $PlcName,
    "--block", $resolvedBlockName,
    "--output", $exportDir,
    "--include-inconsistent"
)

$summaryOutput = $null
if ($blockInfo.ProgrammingLanguage -eq "LAD") {
    $exportedXml = @(Get-ChildItem -LiteralPath $exportDir -Filter *.xml -File -ErrorAction Stop | Select-Object -ExpandProperty FullName)
    if ($exportedXml.Count -gt 0) {
        $summaryStep = Invoke-PowerShellStep -ScriptPath $invokeScript -Arguments @(
            "summarize-lad",
            "-Path", $exportedXml[0],
            "-OutputPath", $summaryPath
        )
        $summaryOutput = ($summaryStep.Output -join [Environment]::NewLine).Trim()
    }
}

$report = [ordered]@{
    ProjectPath = $projectDir
    InputXml = (Get-Item -LiteralPath $InputXml).FullName
    ReleaseApprovalPath = $ReleaseApprovalPath
    ReleaseApproval = if ($releaseApproval) { $releaseApproval } else { $null }
    PlcName = $PlcName
    BlockName = $resolvedBlockName
    VerificationDirectory = $verifyDir
    BackupOutput = $backupOutput
    DryRunOutput = ($dryRunStep.Output -join [Environment]::NewLine).Trim()
    ApplyOutput = ($applyStep.Output -join [Environment]::NewLine).Trim()
    CompileOutput = ($compileStep.Output -join [Environment]::NewLine).Trim()
    ExportOutput = ($exportStep.Output -join [Environment]::NewLine).Trim()
    SummaryOutput = $summaryOutput
    CompileExitCode = $compileStep.ExitCode
} | ConvertTo-Json -Depth 6

Set-Content -LiteralPath $reportPath -Value $report -Encoding UTF8

[pscustomobject]@{
    VerificationDirectory = $verifyDir
    ReportPath = $reportPath
    CompileExitCode = $compileStep.ExitCode
    SummaryPath = if (Test-Path -LiteralPath $summaryPath) { $summaryPath } else { $null }
} | ConvertTo-Json -Depth 4
