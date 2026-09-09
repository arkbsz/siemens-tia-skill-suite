param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [string]$OutputPath
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$summarizer = Join-Path $scriptDir "summarize-lad-xml.ps1"

if (-not (Test-Path -LiteralPath $summarizer)) {
    throw "Missing summarize-lad-xml.ps1 next to this script."
}

$item = Get-Item -LiteralPath $Path
$files = if ($item.PSIsContainer) {
    @(Get-ChildItem -LiteralPath $item.FullName -Recurse -File | Where-Object { $_.Extension -ieq ".xml" })
} else {
    @($item)
}

if ($files.Count -eq 0) {
    throw "No XML files found at $Path"
}

$entries = @()

foreach ($file in $files) {
    $json = & $summarizer -Path $file.FullName -Format Json
    $summary = @($json | ConvertFrom-Json)
    foreach ($block in $summary) {
        foreach ($network in @($block.Networks)) {
            $signature = ""
            if (@($network.Conditions).Count -gt 0 -and @($network.Actions).Count -gt 0) {
                $signature = "IF " + (@($network.Conditions) -join " AND ") + " THEN " + (@($network.Actions) -join "; ")
            }
            elseif (@($network.Actions).Count -gt 0) {
                $signature = @($network.Actions) -join "; "
            }
            elseif (@($network.Elements).Count -gt 0) {
                $signature = @($network.Elements) -join "; "
            }

            $entries += [pscustomobject]@{
                Block = $block.Block
                File = $block.File
                NetworkIndex = $network.Index
                Title = if ($network.Title) { $network.Title } else { "(untitled)" }
                Comment = $network.Comment
                Signature = $signature
                Symbols = @($network.Symbols)
            }
        }
    }
}

$entries = @($entries)

$lines = @()
$lines += "# LAD Template Catalog"
$lines += ""
$lines += "| Block | Network | Title | Signature |"
$lines += "| --- | ---: | --- | --- |"

foreach ($entry in $entries) {
    $signature = if ($entry.Signature) { $entry.Signature } else { "" }
    $signature = $signature.Replace("|", "\|")
    $title = $entry.Title.Replace("|", "\|")
    $block = $entry.Block.Replace("|", "\|")
    $lines += "| $block | $($entry.NetworkIndex) | $title | $signature |"
}

$markdown = $lines -join [Environment]::NewLine

if ($OutputPath) {
    $outputDir = Split-Path -Parent $OutputPath
    if ($outputDir) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    Set-Content -LiteralPath $OutputPath -Value $markdown -Encoding UTF8
    $jsonPath = [System.IO.Path]::ChangeExtension($OutputPath, ".json")
    $entries | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
    [pscustomobject]@{
        OutputPath = (Get-Item -LiteralPath $OutputPath).FullName
        JsonPath = (Get-Item -LiteralPath $jsonPath).FullName
        Networks = $entries.Count
    } | ConvertTo-Json -Depth 4
}
else {
    $markdown
}
