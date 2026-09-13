param(
    [string]$FixtureXml = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$skillRoot = Split-Path -Parent $PSScriptRoot
$diffScript = Join-Path $skillRoot "scripts\lad-diff.ps1"
if ([string]::IsNullOrWhiteSpace($FixtureXml)) {
    throw "FixtureXml is required. Pass a real exported LAD XML with -FixtureXml."
}
$fixture = (Resolve-Path -LiteralPath $FixtureXml -ErrorAction Stop).Path

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("SiemensTiaLadDiff-" + [guid]::NewGuid().ToString("N"))
$candidate = Join-Path $tempRoot "candidate.xml"
$sameReport = Join-Path $tempRoot "same.md"
$sameJson = Join-Path $tempRoot "same.json"
$changedReport = Join-Path $tempRoot "changed.md"
$changedJson = Join-Path $tempRoot "changed.json"
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

try {
    $document = New-Object System.Xml.XmlDocument
    $document.PreserveWhitespace = $true
    $document.XmlResolver = $null
    $document.Load($fixture)
    $titleNode = $document.SelectSingleNode("//*[local-name()='SW.Blocks.CompileUnit']//*[local-name()='MultilingualText'][@CompositionName='Title']//*[local-name()='Text']")
    if ($null -eq $titleNode) {
        throw "The fixture does not contain a network title node."
    }
    $titleNode.InnerText = "LAD diff regression title"
    $document.Save($candidate)

    $sameOutput = @(
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $diffScript `
            -BaseXml $fixture -CandidateXml $fixture `
            -OutputPath $sameReport -JsonOutputPath $sameJson
    )
    if ($LASTEXITCODE -ne 0) {
        throw "Unchanged LAD diff invocation failed."
    }
    $same = Get-Content -LiteralPath $sameJson -Raw -Encoding UTF8 | ConvertFrom-Json
    if ([int]$same.summary.Modified -ne 0 -or
        [int]$same.summary.Added -ne 0 -or
        [int]$same.summary.Removed -ne 0 -or
        [int]$same.summary.Unchanged -ne [int]$same.summary.Total) {
        throw "Unchanged LAD diff result was unexpected."
    }

    $changedOutput = @(
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $diffScript `
            -BaseXml $fixture -CandidateXml $candidate `
            -OutputPath $changedReport -JsonOutputPath $changedJson
    )
    if ($LASTEXITCODE -ne 0) {
        throw "Changed LAD diff invocation failed."
    }
    $changed = Get-Content -LiteralPath $changedJson -Raw -Encoding UTF8 | ConvertFrom-Json
    if ([int]$changed.summary.Modified -ne 1) {
        throw "Changed LAD diff did not report exactly one modified network."
    }
    if ($changed.networks[0].Change -ne "MODIFIED") {
        throw "Changed LAD diff did not mark network 1 as MODIFIED."
    }
    if (-not (Test-Path -LiteralPath $changedReport -PathType Leaf)) {
        throw "Changed LAD Markdown evidence was not written."
    }

    [pscustomobject]@{
        Status = "Passed"
        Fixture = $fixture
        TotalNetworks = [int]$changed.summary.Total
        UnchangedCase = "Passed"
        ChangedCase = "Passed"
        ModifiedNetworks = [int]$changed.summary.Modified
        Evidence = $changedReport
        JsonEvidence = $changedJson
    } | ConvertTo-Json -Depth 8
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        try {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
        catch {
        }
    }
}
