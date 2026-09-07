param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    [string]$PlcName = "",

    [string]$RunName = "",

    [string[]]$Languages = @("LAD", "FBD", "SCL"),

    [string]$WorkflowConfigPath = "",

    [switch]$UseUi,

    [switch]$Attach,

    [switch]$SkipExport
)

$ErrorActionPreference = "Stop"

function Invoke-CapturedPowerShell {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [Parameter(Mandatory = $true)]
        [string]$LogPath
    )

    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $text = ($output | Out-String).TrimEnd()
    $text | Set-Content -LiteralPath $LogPath -Encoding UTF8

    return [pscustomobject]@{
        ExitCode = $exitCode
        Output = $text
        LogPath = $LogPath
    }
}

function Stop-OnFailedLiveCommand {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Result,

        [Parameter(Mandatory = $true)]
        [string]$StepName
    )

    if ($Result.ExitCode -eq 0) {
        return
    }

    $hint = "See log: $($Result.LogPath)"
    if ($Result.Output -match "EngineeringSecurityException|Security error|timed out|timeout") {
        $hint = "Openness security handshake failed. Run read-cycle once with -UseUi and accept the Siemens Openness trust prompt, or open the project manually in TIA Portal and rerun with -Attach. $hint"
    }

    throw "$StepName failed with exit code $($Result.ExitCode). $hint"
}

function Test-NoMatchingExportBlocks {
    param([string]$Text)

    return ($Text -match "SUMMARY\s+ExportedBlocks\s+0") -and
        ($Text -match "SUMMARY\s+FailedBlocks\s+0")
}

function Convert-PlcListOutputToRows {
    param([string]$Text)

    $rows = New-Object System.Collections.Generic.List[object]
    $seenHeader = $false
    $lines = @($Text -split "`r?`n" | Where-Object { $_.Trim().Length -gt 0 })
    foreach ($line in $lines) {
        if ($line -match "^Device`tItemPath`tSoftware$") {
            $seenHeader = $true
            continue
        }

        if (-not $seenHeader) {
            continue
        }

        $parts = $line -split "`t"
        if ($parts.Count -ge 3) {
            $rows.Add([pscustomobject]@{
                Device = $parts[0]
                ItemPath = $parts[1]
                Software = $parts[2]
            })
        }
    }

    return $rows.ToArray()
}

function New-Readme {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [object]$Report
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("# PLC read-cycle report")
    $lines.Add("")
    $lines.Add(('- Project: `{0}`' -f $Report.ProjectPath))
    $lines.Add(('- PLC: `{0}`' -f $Report.PlcName))
    $lines.Add(('- Started: `{0}`' -f $Report.StartedAt))
    $lines.Add(('- Completed: `{0}`' -f $Report.CompletedAt))
    $lines.Add(('- Used UI: `{0}`' -f $Report.UsedUi))
    $lines.Add(('- Attached to TIA: `{0}`' -f $Report.Attached))
    $lines.Add("")
    $lines.Add("## Outputs")
    $lines.Add("")
    $lines.Add(('- Probe log: `{0}`' -f $Report.Logs.Probe))
    $lines.Add(('- PLC list log: `{0}`' -f $Report.Logs.ListPlcs))
    $lines.Add(('- Block list log: `{0}`' -f $Report.Logs.ListBlocks))
    $lines.Add(('- Exports: `{0}`' -f $Report.ExportRoot))
    $lines.Add(('- Reports: `{0}`' -f $Report.ReportRoot))
    $lines.Add("")
    $lines.Add("## Next workflow")
    $lines.Add("")
    $lines.Add("1. Review `reports/block-list.txt` and `reports/lad/*.lad.md`.")
    $lines.Add("2. Make LAD edits through JSON specs or patch a donor network from exported XML.")
    $lines.Add("3. Verify on a cloned project with `verify-lad-change` before applying to the real project.")
    $lines.Add("4. Re-export after compile so exported XML remains the reviewable source of truth.")
    $lines.Add("")
    $lines -join [Environment]::NewLine | Set-Content -LiteralPath $Path -Encoding UTF8
}

$startedAt = Get-Date
$projectItem = Get-Item -LiteralPath $ProjectPath
$resolvedProjectPath = $projectItem.FullName
$projectDir = if ($projectItem.PSIsContainer) { $projectItem.FullName } else { $projectItem.Directory.FullName }
$workflowConfig = $null
if (-not [string]::IsNullOrWhiteSpace($WorkflowConfigPath)) {
    if (-not (Test-Path -LiteralPath $WorkflowConfigPath)) {
        throw "Workflow config not found: $WorkflowConfigPath"
    }
    $WorkflowConfigPath = (Get-Item -LiteralPath $WorkflowConfigPath).FullName
    $workflowConfig = Get-Content -LiteralPath $WorkflowConfigPath -Raw | ConvertFrom-Json

    if ([string]::IsNullOrWhiteSpace($PlcName) -and $workflowConfig.tia.plcName) {
        $PlcName = [string]$workflowConfig.tia.plcName
    }
    if (-not $PSBoundParameters.ContainsKey("Languages")) {
        switch ([string]$workflowConfig.routing.languagePreference) {
            "FBD优先" { $Languages = @("FBD", "LAD", "SCL") }
            "SCL优先" { $Languages = @("SCL", "LAD", "FBD") }
            default { $Languages = @("LAD", "FBD", "SCL") }
        }
    }
    if (-not $UseUi -and -not $Attach) {
        if ([string]$workflowConfig.tia.sessionMode -eq "显示TIA界面") {
            $UseUi = $true
        }
        else {
            $Attach = $true
        }
    }
}

if ([string]::IsNullOrWhiteSpace($RunName)) {
    $RunName = "read-cycle-" + (Get-Date -Format "yyyyMMdd-HHmmss")
}

$workspaceRoot = Join-Path $projectDir "PLC_Code"
$runRoot = Join-Path (Join-Path $workspaceRoot "runs") $RunName
$logRoot = Join-Path $runRoot "logs"
$exportRoot = Join-Path $runRoot "exports"
$reportRoot = Join-Path $runRoot "reports"
$ladReportRoot = Join-Path $reportRoot "lad"

New-Item -ItemType Directory -Path $logRoot, $exportRoot, $reportRoot, $ladReportRoot -Force | Out-Null
$workflowConfigSnapshotPath = ""
if ($workflowConfig) {
    $workflowConfigSnapshotPath = Join-Path $reportRoot "workflow-config.snapshot.json"
    $workflowConfig | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $workflowConfigSnapshotPath -Encoding UTF8
}

$skillsRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $PSScriptRoot "resolve-bridge-skill.ps1")
$bridge = Resolve-TiaBridgeSkill -SkillsRoot $skillsRoot
$opennessScript = Resolve-TiaBridgeScript -SkillPath $bridge.SkillPath -Candidates @("scripts\invoke-tia-openness.ps1")
$probeScript = Resolve-TiaBridgeScript -SkillPath $bridge.SkillPath -Candidates @("scripts\probe-tia-portal.ps1", "scripts\probe-tia-v17.ps1")
$summarizeLadScript = Resolve-TiaBridgeScript -SkillPath $bridge.SkillPath -Candidates @("scripts\summarize-lad-xml.ps1")
$buildCatalogScript = Resolve-TiaBridgeScript -SkillPath $bridge.SkillPath -Candidates @("scripts\build-lad-template-catalog.ps1")

$probe = Invoke-CapturedPowerShell -ScriptPath $probeScript -Arguments @("-ProjectPath", $resolvedProjectPath) -LogPath (Join-Path $logRoot "probe.json")
Stop-OnFailedLiveCommand -Result $probe -StepName "probe"

$probeJson = $probe.Output | ConvertFrom-Json
if (-not [bool]$probeJson.ReadyForOpennessSession) {
    $issues = @($probeJson.ReadinessIssues | Where-Object { $_ })
    throw "Openness is not ready. Issues: $($issues -join '; '). Recommended: $($probeJson.RecommendedNextStep)"
}

$sharedLiveArgs = @()
if ($UseUi) {
    $sharedLiveArgs += "--ui"
}
if ($Attach) {
    $sharedLiveArgs += "--attach"
}

$listPlcsArgs = @("list-plcs", "--project", $resolvedProjectPath) + $sharedLiveArgs
$plcList = Invoke-CapturedPowerShell -ScriptPath $opennessScript -Arguments $listPlcsArgs -LogPath (Join-Path $logRoot "list-plcs.txt")
Stop-OnFailedLiveCommand -Result $plcList -StepName "list-plcs"

$plcRows = @(Convert-PlcListOutputToRows -Text $plcList.Output)
if ([string]::IsNullOrWhiteSpace($PlcName)) {
    if ($plcRows.Count -eq 0) {
        throw "No PLC was found in list-plcs output. See log: $($plcList.LogPath)"
    }
    $PlcName = $plcRows[0].ItemPath
}

$listBlocksArgs = @("list-blocks", "--project", $resolvedProjectPath, "--plc", $PlcName) + $sharedLiveArgs
$blockList = Invoke-CapturedPowerShell -ScriptPath $opennessScript -Arguments $listBlocksArgs -LogPath (Join-Path $logRoot "list-blocks.txt")
Stop-OnFailedLiveCommand -Result $blockList -StepName "list-blocks"
$blockList.Output | Set-Content -LiteralPath (Join-Path $reportRoot "block-list.txt") -Encoding UTF8

$exports = New-Object System.Collections.Generic.List[object]
if (-not $SkipExport) {
    foreach ($language in $Languages) {
        $normalizedLanguage = $language.ToUpperInvariant()
        $languageOut = Join-Path $exportRoot $normalizedLanguage
        New-Item -ItemType Directory -Path $languageOut -Force | Out-Null

        $exportArgs = @("export-blocks", "--project", $resolvedProjectPath, "--plc", $PlcName, "--language", $normalizedLanguage, "--output", $languageOut) + $sharedLiveArgs
        $exportLog = Join-Path $logRoot ("export-" + $normalizedLanguage.ToLowerInvariant() + ".txt")
        $exportResult = Invoke-CapturedPowerShell -ScriptPath $opennessScript -Arguments $exportArgs -LogPath $exportLog
        $exportStatus = "OK"
        if ($exportResult.ExitCode -ne 0) {
            if (Test-NoMatchingExportBlocks -Text $exportResult.Output) {
                $exportStatus = "NoMatchingBlocks"
            }
            else {
                Stop-OnFailedLiveCommand -Result $exportResult -StepName "export-$normalizedLanguage"
            }
        }

        $exportedFiles = @(Get-ChildItem -LiteralPath $languageOut -Recurse -File -ErrorAction SilentlyContinue)
        $exports.Add([pscustomobject]@{
            Language = $normalizedLanguage
            Status = $exportStatus
            OutputPath = $languageOut
            LogPath = $exportLog
            FileCount = $exportedFiles.Count
        })
    }
}

$ladExport = $exports | Where-Object { $_.Language -eq "LAD" } | Select-Object -First 1
if ($ladExport -and (Test-Path -LiteralPath $ladExport.OutputPath)) {
    $ladXmlFiles = @(Get-ChildItem -LiteralPath $ladExport.OutputPath -Recurse -Filter "*.xml" -File -ErrorAction SilentlyContinue)
    foreach ($xml in $ladXmlFiles) {
        $summaryPath = Join-Path $ladReportRoot ($xml.BaseName + ".lad.md")
        $summaryResult = Invoke-CapturedPowerShell -ScriptPath $summarizeLadScript -Arguments @("-Path", $xml.FullName, "-OutputPath", $summaryPath) -LogPath (Join-Path $logRoot ("summarize-" + $xml.BaseName + ".txt"))
        Stop-OnFailedLiveCommand -Result $summaryResult -StepName "summarize-lad-$($xml.BaseName)"
    }

    $catalogPath = Join-Path $reportRoot "lad-template-catalog.md"
    $catalogResult = Invoke-CapturedPowerShell -ScriptPath $buildCatalogScript -Arguments @("-Path", $ladExport.OutputPath, "-OutputPath", $catalogPath) -LogPath (Join-Path $logRoot "build-lad-catalog.txt")
    Stop-OnFailedLiveCommand -Result $catalogResult -StepName "build-lad-catalog"
}

$report = [pscustomobject]@{
    StartedAt = $startedAt.ToString("s")
    CompletedAt = (Get-Date).ToString("s")
    ProjectPath = $resolvedProjectPath
    PlcName = $PlcName
    UsedUi = [bool]$UseUi
    Attached = [bool]$Attach
    RunRoot = $runRoot
    ExportRoot = $exportRoot
    ReportRoot = $reportRoot
    ProbeReady = [bool]$probeJson.ReadyForOpennessSession
    DetectedVersion = $probeJson.DetectedVersion
    WorkflowConfigPath = $WorkflowConfigPath
    WorkflowConfigSnapshotPath = $workflowConfigSnapshotPath
    WorkflowConfig = $workflowConfig
    PlcRows = $plcRows
    Exports = $exports
    Logs = [pscustomobject]@{
        Probe = $probe.LogPath
        ListPlcs = $plcList.LogPath
        ListBlocks = $blockList.LogPath
    }
    Notes = @(
        "Use -UseUi for the first Openness trust handshake after install or after helper rebuild.",
        "Use -Attach when the project is already open in TIA Portal.",
        "Do not apply writes to the production project before backup and clone compile verification."
    )
}

$reportPath = Join-Path $runRoot "workflow-report.json"
$readmePath = Join-Path $runRoot "README.md"
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $reportPath -Encoding UTF8
New-Readme -Path $readmePath -Report $report

$report | ConvertTo-Json -Depth 8
