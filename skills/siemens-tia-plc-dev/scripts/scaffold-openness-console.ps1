param(
    [Parameter(Mandatory = $true)]
    [string]$TargetDirectory,

    [string]$ProjectName = "TiaOpennessConsole"
)

$ErrorActionPreference = "Stop"

$templateRoot = Join-Path (Split-Path -Parent $PSScriptRoot) "templates\openness-console"
if (-not (Test-Path -LiteralPath $templateRoot)) {
    throw "Template root not found: $templateRoot"
}

$targetRoot = Join-Path (Resolve-Path -LiteralPath (Split-Path -Parent $TargetDirectory)).Path (Split-Path -Leaf $TargetDirectory)
New-Item -ItemType Directory -Path $targetRoot -Force | Out-Null

Get-ChildItem -LiteralPath $templateRoot -Recurse -File | ForEach-Object {
    $relative = $_.FullName.Substring($templateRoot.Length).TrimStart('\')
    $relative = $relative.Replace("__PROJECT_NAME__", $ProjectName)
    $destination = Join-Path $targetRoot $relative
    $destinationDir = Split-Path -Parent $destination
    if (-not (Test-Path -LiteralPath $destinationDir)) {
        New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
    }

    $content = Get-Content -LiteralPath $_.FullName -Raw
    $content = $content.Replace("__PROJECT_NAME__", $ProjectName)
    Set-Content -LiteralPath $destination -Value $content -Encoding UTF8
}

[pscustomobject]@{
    TargetDirectory = $targetRoot
    ProjectName = $ProjectName
    Files = @(
        "$ProjectName.csproj",
        "Program.cs",
        "README.md"
    )
} | ConvertTo-Json -Depth 4
