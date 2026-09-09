param(
    [Parameter(Mandatory = $true)]
    [string]$SourceXml,

    [Parameter(Mandatory = $true)]
    [int]$NetworkIndex,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [string]$TemplateName,

    [string]$Category = "general",

    [string]$Description = ""
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$summarizer = Join-Path $scriptDir "summarize-lad-xml.ps1"

if (-not (Test-Path -LiteralPath $SourceXml)) {
    throw "Source XML not found: $SourceXml"
}
if (-not (Test-Path -LiteralPath $summarizer)) {
    throw "Missing summarize-lad-xml.ps1 next to this script."
}

$json = & $summarizer -Path $SourceXml -Format Json
$summary = @($json | ConvertFrom-Json)
if ($summary.Count -eq 0) {
    throw "No summary returned for $SourceXml"
}

$block = $summary[0]
$network = @($block.Networks | Where-Object { $_.Index -eq $NetworkIndex }) | Select-Object -First 1
if (-not $network) {
    throw "NetworkIndex $NetworkIndex not found in $SourceXml"
}

if (-not $TemplateName) {
    $baseTitle = if ($network.Title) { $network.Title } else { "network-$NetworkIndex" }
    $normalized = ($baseTitle -replace '[^\p{L}\p{Nd}]+', '-').Trim('-').ToLowerInvariant()
    if (-not $normalized) { $normalized = "network-$NetworkIndex" }
    $TemplateName = $normalized
}

$symbols = @($network.Symbols)
$replaceHints = @()
foreach ($symbol in $symbols) {
    $replaceHints += [pscustomobject]@{
        from = $symbol
        to = ""
        note = "Fill in a replacement symbol only when reusing this network."
    }
}

$applyExample = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$env:USERPROFILE\.codex\skills\tia-portal-v17\scripts\apply-lad-template-replacements.ps1`" -SourceXml `"$SourceXml`" -OutputXml `"D:\path\to\generated.xml`" -NetworkIndex $NetworkIndex -Replace `"Old=New`""

$template = [pscustomobject]@{
    templateName = $TemplateName
    category = $Category
    description = $Description
    source = [pscustomobject]@{
        block = $block.Block
        xml = (Get-Item -LiteralPath $SourceXml).FullName
        networkIndex = $NetworkIndex
        title = $network.Title
        comment = $network.Comment
    }
    summary = [pscustomobject]@{
        signature = if (@($network.Conditions).Count -gt 0 -or @($network.Actions).Count -gt 0) {
            ("IF " + (@($network.Conditions) -join " AND ") + " THEN " + (@($network.Actions) -join "; ")).Trim()
        } elseif (@($network.Elements).Count -gt 0) {
            @($network.Elements) -join "; "
        } else {
            ""
        }
        conditions = @($network.Conditions)
        actions = @($network.Actions)
        elements = @($network.Elements)
        symbols = $symbols
    }
    replaceHints = $replaceHints
    workflow = [pscustomobject]@{
        validateCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$env:USERPROFILE\.codex\skills\tia-portal-v17\scripts\validate-lad-xml.ps1`" -Path `"D:\path\to\generated.xml`""
        summarizeCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$env:USERPROFILE\.codex\skills\tia-portal-v17\scripts\summarize-lad-xml.ps1`" -Path `"D:\path\to\generated.xml`" -OutputPath `"D:\path\to\generated.lad.md`""
        applyTemplateExample = $applyExample
    }
} | ConvertTo-Json -Depth 8

$outputDir = Split-Path -Parent $OutputPath
if ($outputDir) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}
Set-Content -LiteralPath $OutputPath -Value $template -Encoding UTF8

[pscustomobject]@{
    OutputPath = (Get-Item -LiteralPath $OutputPath).FullName
    TemplateName = $TemplateName
    SourceBlock = $block.Block
    NetworkIndex = $NetworkIndex
} | ConvertTo-Json -Depth 4
