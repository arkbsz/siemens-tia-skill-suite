param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    [Parameter(Mandatory = $true)]
    [string]$InputXml,

    [Parameter(Mandatory = $true)]
    [string]$PlcName,

    [string]$ChangeName,

    [string]$CloneName,

    [string]$CloneRoot,

    [string]$SupportingSourceDir
)

$ErrorActionPreference = "Stop"

function Get-BlockNameFromXml {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $xml = New-Object System.Xml.XmlDocument
    $xml.PreserveWhitespace = $true
    $xml.Load($Path)

    $blockNode = @($xml.DocumentElement.ChildNodes | Where-Object { $_.LocalName -like "SW.Blocks.*" } | Select-Object -First 1)[0]
    if (-not $blockNode) {
        throw "Unable to determine block name from XML: $Path"
    }

    $nameNode = $blockNode.SelectSingleNode("./*[local-name()='AttributeList']/*[local-name()='Name']")
    if (-not $nameNode -or [string]::IsNullOrWhiteSpace($nameNode.InnerText)) {
        throw "Block XML does not contain a readable block name: $Path"
    }

    return $nameNode.InnerText.Trim()
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

function Assert-OpennessSessionReady {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InvokeScript,

        [Parameter(Mandatory = $true)]
        [string]$ProjectPath
    )

    $probeStep = Invoke-PowerShellStep -ScriptPath $InvokeScript -Arguments @(
        "probe",
        "-ProjectPath", $ProjectPath
    )

    $probeText = ($probeStep.Output -join [Environment]::NewLine).Trim()
    try {
        $probe = $probeText | ConvertFrom-Json
    }
    catch {
        throw "Openness probe returned unreadable JSON before clone verification.`n$probeText"
    }

    $ready = if ($probe.PSObject.Properties.Name -contains "ReadyForOpennessSession") {
        [bool]$probe.ReadyForOpennessSession
    }
    else {
        [bool]$probe.ConfiguredInSiemensTiaOpennessGroup -and [bool]$probe.ActiveInCurrentLogonToken
    }

    if (-not $ready) {
        $issues = @($probe.ReadinessIssues | Where-Object { $_ })
        if ($issues.Count -eq 0) {
            if (-not [bool]$probe.ConfiguredInSiemensTiaOpennessGroup) {
                $issues = @("Current Windows user is not configured in the 'Siemens TIA Openness' local group.")
            }
            elseif (-not [bool]$probe.ActiveInCurrentLogonToken) {
                $issues = @("Current Windows logon session does not yet contain the 'Siemens TIA Openness' group.")
            }
            else {
                $issues = @("Unknown Openness readiness problem.")
            }
        }

        $issueText = ($issues | ForEach-Object { "- $_" }) -join [Environment]::NewLine
        $recommended = if ($probe.PSObject.Properties.Name -contains "RecommendedNextStep" -and $probe.RecommendedNextStep) {
            $probe.RecommendedNextStep
        }
        else {
            "Fix the Openness prerequisites first, then rerun verify-lad-change."
        }

        throw "Openness preflight failed before clone/import/compile.`n$issueText`nRecommended next step: $recommended"
    }

    return $probe
}

if (-not (Test-Path -LiteralPath $InputXml)) {
    throw "Input XML not found: $InputXml"
}

if (-not $SupportingSourceDir) {
    $candidateSupportDir = Join-Path (Split-Path -Parent $InputXml) "supporting-sources"
    if (Test-Path -LiteralPath $candidateSupportDir) {
        $SupportingSourceDir = $candidateSupportDir
    }
}

if ($SupportingSourceDir -and -not (Test-Path -LiteralPath $SupportingSourceDir)) {
    throw "Supporting source directory not found: $SupportingSourceDir"
}

$invokeScript = Join-Path $PSScriptRoot "invoke-siemens-plc-dev.ps1"
$cloneScript = Join-Path $PSScriptRoot "clone-project-for-edit.ps1"

foreach ($path in @($invokeScript, $cloneScript)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing dependency script: $path"
    }
}

$projectItem = Get-Item -LiteralPath $ProjectPath
$projectDir = if ($projectItem.PSIsContainer) { $projectItem.FullName } else { $projectItem.Directory.FullName }
$workspacePath = Join-Path $projectDir "PLC_Code"
$verificationRoot = Join-Path $workspacePath "verification"
New-Item -ItemType Directory -Path $verificationRoot -Force | Out-Null

if (-not $CloneRoot) {
    $CloneRoot = Join-Path $verificationRoot "_clones"
}

New-Item -ItemType Directory -Path $CloneRoot -Force | Out-Null

Write-Host "[verify-lad-change] probing Openness readiness"
$opennessProbe = Assert-OpennessSessionReady -InvokeScript $invokeScript -ProjectPath $ProjectPath

$blockName = Get-BlockNameFromXml -Path $InputXml
$resolvedChangeName = if ($ChangeName) { $ChangeName } else { [System.IO.Path]::GetFileNameWithoutExtension($InputXml) }
$safeChangeName = (($resolvedChangeName -replace '[\\/:*?"<>| ]+', "-").Trim("-"))
if ([string]::IsNullOrWhiteSpace($safeChangeName)) {
    $safeChangeName = "lad-change"
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$verificationDir = Join-Path $verificationRoot ($safeChangeName + "_" + $timestamp)
$exportDir = Join-Path $verificationDir "post-import-export"
$reportPath = Join-Path $verificationDir "verify-report.json"
$summaryPath = Join-Path $verificationDir ($safeChangeName + ".post-import.lad.md")

New-Item -ItemType Directory -Path $verificationDir -Force | Out-Null
New-Item -ItemType Directory -Path $exportDir -Force | Out-Null

$resolvedCloneName = if ($CloneName) { $CloneName } else { "codex_verify_" + $safeChangeName + "_" + $timestamp }

Write-Host "[verify-lad-change] clone-root: $CloneRoot"
Write-Host "[verify-lad-change] verification-dir: $verificationDir"
Write-Host "[verify-lad-change] cloning project as: $resolvedCloneName"
$cloneStep = Invoke-PowerShellStep -ScriptPath $cloneScript -Arguments @(
    "-ProjectPath", $ProjectPath,
    "-CloneRoot", $CloneRoot,
    "-CloneName", $resolvedCloneName
)

$cloneInfo = ($cloneStep.Output -join [Environment]::NewLine) | ConvertFrom-Json
$clonePath = $cloneInfo.ClonePath

$supportingSourceStep = $null
if ($SupportingSourceDir) {
    Write-Host "[verify-lad-change] importing supporting sources from: $SupportingSourceDir"
    $supportingSourceStep = Invoke-PowerShellStep -ScriptPath $invokeScript -Arguments @(
        "import-sources",
        "--project", $clonePath,
        "--plc", $PlcName,
        "--source-dir", $SupportingSourceDir,
        "--save"
    )
}

Write-Host "[verify-lad-change] importing block XML: $InputXml"
$importStep = Invoke-PowerShellStep -ScriptPath $invokeScript -Arguments @(
    "import-blocks",
    "--project", $clonePath,
    "--input", $InputXml,
    "--plc", $PlcName,
    "--apply"
)

Write-Host "[verify-lad-change] compiling PLC: $PlcName"
$compileStep = Invoke-PowerShellStep -ScriptPath $invokeScript -Arguments @(
    "compile-plc",
    "--project", $clonePath,
    "--plc", $PlcName,
    "--save"
) -AllowedExitCodes @(0, 1)

Write-Host "[verify-lad-change] exporting block: $blockName"
$exportStep = Invoke-PowerShellStep -ScriptPath $invokeScript -Arguments @(
    "export-blocks",
    "--project", $clonePath,
    "--plc", $PlcName,
    "--block", $blockName,
    "--output", $exportDir,
    "--include-inconsistent"
)

$exportedXml = @(Get-ChildItem -LiteralPath $exportDir -Filter *.xml -File -ErrorAction Stop | Select-Object -ExpandProperty FullName)
if ($exportedXml.Count -eq 0) {
    throw "No exported XML was produced in $exportDir"
}

$summaryStep = Invoke-PowerShellStep -ScriptPath $invokeScript -Arguments @(
    "summarize-lad",
    "-Path", $exportedXml[0],
    "-OutputPath", $summaryPath
)

$report = [ordered]@{
    ProjectPath = $projectDir
    InputXml = (Get-Item -LiteralPath $InputXml).FullName
    PlcName = $PlcName
    BlockName = $blockName
    VerificationDirectory = $verificationDir
    CloneRoot = $CloneRoot
    ClonePath = $clonePath
    ExportedXml = $exportedXml[0]
    SummaryPath = $summaryPath
    ProbeReady = if ($opennessProbe.PSObject.Properties.Name -contains "ReadyForOpennessSession") { $opennessProbe.ReadyForOpennessSession } else { $null }
    ProbeRecommendedNextStep = if ($opennessProbe.PSObject.Properties.Name -contains "RecommendedNextStep") { $opennessProbe.RecommendedNextStep } else { "" }
    SupportingSourceDir = if ($SupportingSourceDir) { (Get-Item -LiteralPath $SupportingSourceDir).FullName } else { "" }
    SupportingSourceExitCode = if ($supportingSourceStep) { $supportingSourceStep.ExitCode } else { $null }
    ImportExitCode = $importStep.ExitCode
    CompileExitCode = $compileStep.ExitCode
    ExportExitCode = $exportStep.ExitCode
    CloneOutput = ($cloneStep.Output -join [Environment]::NewLine).Trim()
    SupportingSourceOutput = if ($supportingSourceStep) { ($supportingSourceStep.Output -join [Environment]::NewLine).Trim() } else { "" }
    ImportOutput = ($importStep.Output -join [Environment]::NewLine).Trim()
    CompileOutput = ($compileStep.Output -join [Environment]::NewLine).Trim()
    ExportOutput = ($exportStep.Output -join [Environment]::NewLine).Trim()
    SummaryOutput = ($summaryStep.Output -join [Environment]::NewLine).Trim()
} | ConvertTo-Json -Depth 6

Set-Content -LiteralPath $reportPath -Value $report -Encoding UTF8
Write-Host "[verify-lad-change] report written: $reportPath"

[pscustomobject]@{
    VerificationDirectory = $verificationDir
    ClonePath = $clonePath
    BlockName = $blockName
    ExportedXml = $exportedXml[0]
    SummaryPath = $summaryPath
    ReportPath = $reportPath
    CompileExitCode = $compileStep.ExitCode
} | ConvertTo-Json -Depth 5
