param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    [Parameter(Mandatory = $true)]
    [string]$SourceXml,

    [Parameter(Mandatory = $true)]
    [string]$ChangeName,

    [int]$NetworkIndex,

    [switch]$CreateTemplate
)

$ErrorActionPreference = "Stop"

$skillsRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$v17Skill = Join-Path $skillsRoot "tia-portal-v17"

$summarizeScript = Join-Path $v17Skill "scripts\summarize-lad-xml.ps1"
$validateScript = Join-Path $v17Skill "scripts\validate-lad-xml.ps1"
$exportTemplateScript = Join-Path $v17Skill "scripts\export-lad-network-template.ps1"

foreach ($path in @($summarizeScript, $validateScript)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing dependency script: $path"
    }
}

if (-not (Test-Path -LiteralPath $SourceXml)) {
    throw "Source XML not found: $SourceXml"
}

$projectItem = Get-Item -LiteralPath $ProjectPath
$projectDir = if ($projectItem.PSIsContainer) { $projectItem.FullName } else { $projectItem.Directory.FullName }
$workspacePath = Join-Path $projectDir "PLC_Code"
$changesRoot = Join-Path $workspacePath "changes"
$safeChangeName = (($ChangeName -replace '[\\/:*?"<>| ]+', "-").Trim("-"))
if ([string]::IsNullOrWhiteSpace($safeChangeName)) {
    throw "ChangeName does not contain any usable file name characters."
}

$changeDir = Join-Path $changesRoot $safeChangeName
$inputsDir = Join-Path $changeDir "inputs"
$outputsDir = Join-Path $changeDir "outputs"
$reportsDir = Join-Path $changeDir "reports"
$notesDir = Join-Path $changeDir "notes"

foreach ($path in @($changesRoot, $changeDir, $inputsDir, $outputsDir, $reportsDir, $notesDir)) {
    New-Item -ItemType Directory -Path $path -Force | Out-Null
}

$sourceName = Split-Path -Leaf $SourceXml
$sourceCopy = Join-Path $inputsDir $sourceName
$generatedCopy = Join-Path $outputsDir ($safeChangeName + ".generated.xml")
$summaryPath = Join-Path $reportsDir ($safeChangeName + ".lad.md")
$templatePath = $null

Copy-Item -LiteralPath $SourceXml -Destination $sourceCopy -Force
Copy-Item -LiteralPath $SourceXml -Destination $generatedCopy -Force

& $validateScript -Path $sourceCopy | Out-Null
& $summarizeScript -Path $sourceCopy -OutputPath $summaryPath | Out-Null

if ($CreateTemplate) {
    if ($NetworkIndex -lt 1) {
        throw "-CreateTemplate requires -NetworkIndex with a value greater than 0."
    }

    if (-not (Test-Path -LiteralPath $exportTemplateScript)) {
        throw "Missing dependency script: $exportTemplateScript"
    }

    $templatesDir = Join-Path $workspacePath "templates\lad"
    New-Item -ItemType Directory -Path $templatesDir -Force | Out-Null
    $templatePath = Join-Path $templatesDir ($safeChangeName + ".template.json")
    & $exportTemplateScript -SourceXml $sourceCopy -NetworkIndex $NetworkIndex -OutputPath $templatePath -TemplateName $safeChangeName | Out-Null
}

$readmePath = Join-Path $changeDir "README.md"
@"
# LAD Change Package

This folder is a code-like working set for one ladder change.

Files:

- inputs/$(Split-Path -Leaf $sourceCopy) is the untouched export snapshot.
- outputs/$(Split-Path -Leaf $generatedCopy) is the editable working copy.
- reports/$(Split-Path -Leaf $summaryPath) is the readable ladder summary.
- notes/ is for review notes, mappings, and assumptions.

Recommended loop:

1. Edit the generated XML in outputs/.
2. Run invoke-siemens-plc-dev.ps1 validate-lad -Path "<generated xml>".
3. Rebuild the summary with summarize-lad.
4. Preview import with import-blocks on a backup project.
5. Compile with compile-plc --save.
"@ | Set-Content -LiteralPath $readmePath -Encoding UTF8

[pscustomobject]@{
    ProjectPath = $projectDir
    ChangeDirectory = $changeDir
    SourceCopy = $sourceCopy
    GeneratedXml = $generatedCopy
    SummaryPath = $summaryPath
    TemplatePath = $templatePath
    ReadmePath = $readmePath
} | ConvertTo-Json -Depth 5
