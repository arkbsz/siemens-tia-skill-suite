param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    [Parameter(Mandatory = $true)]
    [string]$InputXml,

    [string]$PlcName = "PLC_1",

    [string]$ChangeName = "",

    [string]$ReleaseName = "",

    [string]$RunName = "",

    [string]$CloneRoot = "",

    [string]$CloneName = "",

    [string]$SupportingSourceDir = "",

    [string]$WorkflowConfigPath = "",

    [int]$StepTimeoutSeconds = 600,

    [switch]$SkipRelease
)

$ErrorActionPreference = "Stop"

function Invoke-CapturedPowerShell {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [Parameter(Mandatory = $true)]
        [string]$LogPath,

        [string]$StepName = "step",

        [int[]]$AllowedExitCodes = @(0)
    )

    $started = Get-Date
    if ($script:StepMarkerPath) {
        [pscustomobject]@{
            Step = $StepName
            StartedAt = $started.ToString("s")
            Script = $ScriptPath
            LogPath = $LogPath
        } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $script:StepMarkerPath -Encoding UTF8
    }

    Write-Host ("[write-cycle] {0}" -f $StepName)

    $stdoutPath = $LogPath + ".stdout.tmp"
    $stderrPath = $LogPath + ".stderr.tmp"
    foreach ($tempPath in @($stdoutPath, $stderrPath, $LogPath)) {
        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -LiteralPath $tempPath -Force
        }
    }

    $argumentList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $ScriptPath) + $Arguments
    $process = Start-Process -FilePath "powershell.exe" -ArgumentList $argumentList -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -WindowStyle Hidden -PassThru
    while (-not $process.HasExited) {
        $elapsedSeconds = ((Get-Date) - $started).TotalSeconds
        if ($StepTimeoutSeconds -gt 0 -and $elapsedSeconds -gt $StepTimeoutSeconds) {
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            $stdout = if (Test-Path -LiteralPath $stdoutPath) { Get-Content -LiteralPath $stdoutPath -Raw } else { "" }
            $stderr = if (Test-Path -LiteralPath $stderrPath) { Get-Content -LiteralPath $stderrPath -Raw } else { "" }
            @(
                "[write-cycle] TIMEOUT after $StepTimeoutSeconds seconds in step: $StepName",
                "[write-cycle] Script: $ScriptPath",
                "",
                "## STDOUT",
                $stdout,
                "",
                "## STDERR",
                $stderr
            ) -join [Environment]::NewLine | Set-Content -LiteralPath $LogPath -Encoding UTF8
            throw "Step '$StepName' timed out after $StepTimeoutSeconds seconds. See log: $LogPath"
        }

        Start-Sleep -Seconds 1
        $process.Refresh()
    }

    $exitCode = $process.ExitCode
    $stdoutText = if (Test-Path -LiteralPath $stdoutPath) { Get-Content -LiteralPath $stdoutPath -Raw } else { "" }
    $stderrText = if (Test-Path -LiteralPath $stderrPath) { Get-Content -LiteralPath $stderrPath -Raw } else { "" }
    $text = @($stdoutText.TrimEnd(), $stderrText.TrimEnd()) -join [Environment]::NewLine
    $text | Set-Content -LiteralPath $LogPath -Encoding UTF8

    if ($AllowedExitCodes -notcontains $exitCode) {
        throw "Step failed with exit code $exitCode. See log: $LogPath"
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Output = $text
        LogPath = $LogPath
    }
}

function Convert-LastJsonObject {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    $lines = @($Text -split "`r?`n")
    for ($i = $lines.Count - 1; $i -ge 0; $i--) {
        if ($lines[$i].Trim() -ne "{") {
            continue
        }

        $candidate = ($lines[$i..($lines.Count - 1)] -join [Environment]::NewLine)
        try {
            return $candidate | ConvertFrom-Json
        }
        catch {
            continue
        }
    }

    throw "Unable to parse the final JSON object from command output."
}

function New-Readme {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [object]$Report
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("# PLC write-cycle report")
    $lines.Add("")
    $lines.Add(('- Project: `{0}`' -f $Report.ProjectPath))
    $lines.Add(('- PLC: `{0}`' -f $Report.PlcName))
    $lines.Add(('- Input XML: `{0}`' -f $Report.InputXml))
    $lines.Add(('- Status: `{0}`' -f $Report.Status))
    $lines.Add(('- Compile exit code: `{0}`' -f $Report.CompileExitCode))
    $lines.Add("")
    $lines.Add("## Outputs")
    $lines.Add("")
    $lines.Add(('- Verification report: `{0}`' -f $Report.VerificationReportPath))
    $lines.Add(('- Post-import summary: `{0}`' -f $Report.PostImportSummaryPath))
    $lines.Add(('- Release directory: `{0}`' -f $Report.ReleaseDirectory))
    $lines.Add("")
    $lines.Add("## Safety rule")
    $lines.Add("")
    $lines.Add("This command verifies on a cloned project first. It does not modify the production project.")
    $lines.Add("Only use `apply-release` after reviewing the verification report, readable summary, and release package.")
    $lines.Add("")
    $lines -join [Environment]::NewLine | Set-Content -LiteralPath $Path -Encoding UTF8
}

if (-not (Test-Path -LiteralPath $ProjectPath)) {
    throw "Project path not found: $ProjectPath"
}

if (-not (Test-Path -LiteralPath $InputXml)) {
    throw "Input XML not found: $InputXml"
}

$startedAt = Get-Date
$projectItem = Get-Item -LiteralPath $ProjectPath
$projectDir = if ($projectItem.PSIsContainer) { $projectItem.FullName } else { $projectItem.Directory.FullName }
$resolvedInputXml = (Get-Item -LiteralPath $InputXml).FullName
$workflowConfig = $null
if (-not [string]::IsNullOrWhiteSpace($WorkflowConfigPath)) {
    if (-not (Test-Path -LiteralPath $WorkflowConfigPath)) {
        throw "Workflow config not found: $WorkflowConfigPath"
    }
    $WorkflowConfigPath = (Get-Item -LiteralPath $WorkflowConfigPath).FullName
    $workflowConfig = Get-Content -LiteralPath $WorkflowConfigPath -Raw | ConvertFrom-Json

    if (-not $PSBoundParameters.ContainsKey("PlcName") -and $workflowConfig.tia.plcName) {
        $PlcName = [string]$workflowConfig.tia.plcName
    }
    if (-not $PSBoundParameters.ContainsKey("StepTimeoutSeconds") -and $workflowConfig.tia.stepTimeoutSeconds) {
        $StepTimeoutSeconds = [int]$workflowConfig.tia.stepTimeoutSeconds
    }

    $configuredSafetyMode = [string]$workflowConfig.safety.safetyMode
    if ($configuredSafetyMode -eq "只生成不写入") {
        throw "Workflow config safetyMode is '只生成不写入'; write-cycle is disabled."
    }
    if ($configuredSafetyMode -eq "克隆编译验证") {
        $SkipRelease = $true
    }
}

if ([string]::IsNullOrWhiteSpace($RunName)) {
    $RunName = "write-cycle-" + (Get-Date -Format "yyyyMMdd-HHmmss")
}

if ([string]::IsNullOrWhiteSpace($ChangeName)) {
    $ChangeName = [System.IO.Path]::GetFileNameWithoutExtension($resolvedInputXml)
}

if ([string]::IsNullOrWhiteSpace($ReleaseName)) {
    $ReleaseName = $ChangeName
}

$workspaceRoot = Join-Path $projectDir "PLC_Code"
$runRoot = Join-Path (Join-Path $workspaceRoot "runs") $RunName
$logRoot = Join-Path $runRoot "logs"
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
$script:StepMarkerPath = Join-Path $runRoot "current-step.json"
$workflowConfigSnapshotPath = ""
if ($workflowConfig) {
    $workflowConfigSnapshotPath = Join-Path $runRoot "workflow-config.snapshot.json"
    $workflowConfig | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $workflowConfigSnapshotPath -Encoding UTF8
}

$verifyScript = Join-Path $PSScriptRoot "verify-lad-change-on-clone.ps1"
$releaseScript = Join-Path $PSScriptRoot "prepare-plc-release.ps1"
foreach ($dependency in @($verifyScript, $releaseScript)) {
    if (-not (Test-Path -LiteralPath $dependency)) {
        throw "Missing dependency script: $dependency"
    }
}

$verifyArgs = @(
    "-ProjectPath", $ProjectPath,
    "-InputXml", $resolvedInputXml,
    "-PlcName", $PlcName,
    "-ChangeName", $ChangeName
)

if (-not [string]::IsNullOrWhiteSpace($CloneRoot)) {
    $verifyArgs += @("-CloneRoot", $CloneRoot)
}
if (-not [string]::IsNullOrWhiteSpace($CloneName)) {
    $verifyArgs += @("-CloneName", $CloneName)
}
if (-not [string]::IsNullOrWhiteSpace($SupportingSourceDir)) {
    $verifyArgs += @("-SupportingSourceDir", $SupportingSourceDir)
}

$verifyStep = Invoke-CapturedPowerShell -ScriptPath $verifyScript -Arguments $verifyArgs -LogPath (Join-Path $logRoot "verify-lad-change.txt") -StepName "verify-lad-change"
$verifyInfo = Convert-LastJsonObject -Text $verifyStep.Output

$releaseInfo = $null
$releaseLogPath = ""
$status = "Verified"
if ([int]$verifyInfo.CompileExitCode -ne 0) {
    $status = "CompileFailed"
}
elseif (-not $SkipRelease) {
    $releaseArgs = @(
        "-ProjectPath", $ProjectPath,
        "-InputXml", $resolvedInputXml,
        "-ReleaseName", $ReleaseName,
        "-ReadableSummaryPath", $verifyInfo.SummaryPath,
        "-VerificationReportPath", $verifyInfo.ReportPath
    )

    $releaseStep = Invoke-CapturedPowerShell -ScriptPath $releaseScript -Arguments $releaseArgs -LogPath (Join-Path $logRoot "prepare-release.txt") -StepName "prepare-release"
    $releaseInfo = Convert-LastJsonObject -Text $releaseStep.Output
    $releaseLogPath = $releaseStep.LogPath
    $status = "ReleasePrepared"
}

$report = [pscustomobject]@{
    StartedAt = $startedAt.ToString("s")
    CompletedAt = (Get-Date).ToString("s")
    ProjectPath = $projectDir
    InputXml = $resolvedInputXml
    PlcName = $PlcName
    ChangeName = $ChangeName
    ReleaseName = $ReleaseName
    StepTimeoutSeconds = $StepTimeoutSeconds
    WorkflowConfigPath = $WorkflowConfigPath
    WorkflowConfigSnapshotPath = $workflowConfigSnapshotPath
    WorkflowConfig = $workflowConfig
    Status = $status
    RunRoot = $runRoot
    VerificationDirectory = $verifyInfo.VerificationDirectory
    VerificationReportPath = $verifyInfo.ReportPath
    ClonePath = $verifyInfo.ClonePath
    BlockName = $verifyInfo.BlockName
    PostImportExportedXml = $verifyInfo.ExportedXml
    PostImportSummaryPath = $verifyInfo.SummaryPath
    CompileExitCode = [int]$verifyInfo.CompileExitCode
    ReleaseDirectory = if ($releaseInfo) { $releaseInfo.ReleaseDirectory } else { "" }
    ReleaseXml = if ($releaseInfo) { $releaseInfo.ReleaseXml } else { "" }
    ReleaseManifestPath = if ($releaseInfo) { $releaseInfo.ManifestPath } else { "" }
    Logs = [pscustomobject]@{
        Verify = $verifyStep.LogPath
        PrepareRelease = $releaseLogPath
    }
    Notes = @(
        "write-cycle verifies on a cloned project and never writes directly to the production project.",
        "Release packaging is skipped when compile exit code is not 0.",
        "Use apply-release only after reviewing the verification report and readable LAD summary."
    )
}

$reportPath = Join-Path $runRoot "workflow-report.json"
$readmePath = Join-Path $runRoot "README.md"
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $reportPath -Encoding UTF8
New-Readme -Path $readmePath -Report $report

$report | ConvertTo-Json -Depth 8
