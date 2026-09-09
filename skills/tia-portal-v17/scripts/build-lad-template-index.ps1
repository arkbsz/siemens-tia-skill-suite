param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [string]$OutputPath
)

$ErrorActionPreference = "Stop"

$item = Get-Item -LiteralPath $Path
$files = if ($item.PSIsContainer) {
    @(Get-ChildItem -LiteralPath $item.FullName -Recurse -File | Where-Object { $_.Name -like "*.template.json" })
} else {
    @($item)
}

if ($files.Count -eq 0) {
    throw "No template json files found at $Path"
}

$templates = foreach ($file in $files) {
    $template = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
    [pscustomobject]@{
        TemplateName = $template.templateName
        Category = $template.category
        Description = $template.description
        SourceBlock = $template.source.block
        NetworkIndex = $template.source.networkIndex
        Title = $template.source.title
        Signature = $template.summary.signature
        File = $file.FullName
    }
}

$templates = @($templates | Sort-Object Category, TemplateName)

$lines = @()
$lines += "# LAD Template Index"
$lines += ""
$lines += "| Template | Category | Source | Network | Title | Signature |"
$lines += "| --- | --- | --- | ---: | --- | --- |"
foreach ($template in $templates) {
    $signature = if ($template.Signature) { $template.Signature } else { "" }
    $signature = $signature.Replace("|", "\|")
    $title = if ($template.Title) { $template.Title } else { "" }
    $title = $title.Replace("|", "\|")
    $description = $template.TemplateName.Replace("|", "\|")
    $sourceBlock = $template.SourceBlock.Replace("|", "\|")
    $category = $template.Category.Replace("|", "\|")
    $lines += "| $description | $category | $sourceBlock | $($template.NetworkIndex) | $title | $signature |"
}

$markdown = $lines -join [Environment]::NewLine

if ($OutputPath) {
    $outputDir = Split-Path -Parent $OutputPath
    if ($outputDir) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    Set-Content -LiteralPath $OutputPath -Value $markdown -Encoding UTF8
    [pscustomobject]@{
        OutputPath = (Get-Item -LiteralPath $OutputPath).FullName
        Templates = $templates.Count
    } | ConvertTo-Json -Depth 4
}
else {
    $markdown
}
