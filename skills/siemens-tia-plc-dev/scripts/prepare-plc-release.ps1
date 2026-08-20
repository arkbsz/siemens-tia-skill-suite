param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    [Parameter(Mandatory = $true)]
    [string]$InputXml,

    [Parameter(Mandatory = $true)]
    [string]$ReleaseName,

    [string]$ReleaseRoot,

    [string]$ReadableSummaryPath,

    [string]$VerificationReportPath
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

if (-not (Test-Path -LiteralPath $InputXml)) {
    throw "Input XML not found: $InputXml"
}

$invokeScript = Join-Path $PSScriptRoot "invoke-siemens-plc-dev.ps1"
if (-not (Test-Path -LiteralPath $invokeScript)) {
    throw "Missing dependency script: $invokeScript"
}

$projectItem = Get-Item -LiteralPath $ProjectPath
$projectDir = if ($projectItem.PSIsContainer) { $projectItem.FullName } else { $projectItem.Directory.FullName }
$workspacePath = Join-Path $projectDir "PLC_Code"

if (-not $ReleaseRoot) {
    $ReleaseRoot = Join-Path $workspacePath "releases"
}

$safeReleaseName = (($ReleaseName -replace '[\\/:*?"<>| ]+', "-").Trim("-"))
if ([string]::IsNullOrWhiteSpace($safeReleaseName)) {
    throw "ReleaseName does not contain any usable file name characters."
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$releaseDir = Join-Path $ReleaseRoot ($safeReleaseName + "_" + $timestamp)
New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null

$blockInfo = Get-BlockInfoFromXml -Path $InputXml
$xmlCopyPath = Join-Path $releaseDir ($safeReleaseName + ".xml")
$summaryCopyPath = $null
$summaryGeneratedPath = $null
$reportCopyPath = $null

Copy-Item -LiteralPath $InputXml -Destination $xmlCopyPath -Force

if ($ReadableSummaryPath -and (Test-Path -LiteralPath $ReadableSummaryPath)) {
    $summaryCopyPath = Join-Path $releaseDir (Split-Path -Leaf $ReadableSummaryPath)
    Copy-Item -LiteralPath $ReadableSummaryPath -Destination $summaryCopyPath -Force
}
elseif ($blockInfo.ProgrammingLanguage -eq "LAD") {
    $summaryGeneratedPath = Join-Path $releaseDir ($safeReleaseName + ".lad.md")
    $null = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $invokeScript summarize-lad -Path $xmlCopyPath -OutputPath $summaryGeneratedPath 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to generate LAD summary for release package."
    }
}

if ($VerificationReportPath -and (Test-Path -LiteralPath $VerificationReportPath)) {
    $reportCopyPath = Join-Path $releaseDir (Split-Path -Leaf $VerificationReportPath)
    Copy-Item -LiteralPath $VerificationReportPath -Destination $reportCopyPath -Force
}

$manifest = [ordered]@{
    releaseName = $safeReleaseName
    createdAt = (Get-Date).ToString("s")
    projectPath = $projectDir
    sourceXml = (Get-Item -LiteralPath $InputXml).FullName
    blockName = $blockInfo.BlockName
    programmingLanguage = $blockInfo.ProgrammingLanguage
    releaseXml = $xmlCopyPath
    releaseSummary = if ($summaryCopyPath) { $summaryCopyPath } else { $summaryGeneratedPath }
    verificationReport = $reportCopyPath
} | ConvertTo-Json -Depth 5

$manifestPath = Join-Path $releaseDir "release-manifest.json"
Set-Content -LiteralPath $manifestPath -Value $manifest -Encoding UTF8

$readmePath = Join-Path $releaseDir "RELEASE.md"
$readmeLines = @(
    "# PLC Release Package",
    "",
    "Release: $safeReleaseName",
    "Created: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
    "",
    "## Contents",
    "",
    "- XML: $(Split-Path -Leaf $xmlCopyPath)",
    "- Block: $($blockInfo.BlockName)",
    "- Language: $($blockInfo.ProgrammingLanguage)",
    "",
    "## Apply",
    "",
    '```powershell',
    "powershell.exe -NoProfile -ExecutionPolicy Bypass -File ""$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1"" apply-release -ProjectPath ""$projectDir"" -InputXml ""$xmlCopyPath"" -PlcName ""PLC_1""",
    '```'
)
$readme = $readmeLines -join [Environment]::NewLine
Set-Content -LiteralPath $readmePath -Value $readme -Encoding UTF8

[pscustomobject]@{
    ReleaseDirectory = $releaseDir
    ReleaseXml = $xmlCopyPath
    SummaryPath = if ($summaryCopyPath) { $summaryCopyPath } else { $summaryGeneratedPath }
    VerificationReportPath = $reportCopyPath
    ManifestPath = $manifestPath
    ReadmePath = $readmePath
} | ConvertTo-Json -Depth 5
