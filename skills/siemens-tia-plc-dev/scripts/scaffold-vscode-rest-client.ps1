param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath
)

$ErrorActionPreference = "Stop"

$templateRoot = Join-Path (Split-Path -Parent $PSScriptRoot) "templates\vscode-tia-rest-client"
if (-not (Test-Path -LiteralPath $templateRoot)) {
    throw "Template root not found: $templateRoot"
}

$projectRoot = (Resolve-Path -LiteralPath $ProjectPath).Path

Get-ChildItem -LiteralPath $templateRoot -Recurse -Force | ForEach-Object {
    $relative = $_.FullName.Substring($templateRoot.Length).TrimStart('\')
    if ([string]::IsNullOrWhiteSpace($relative)) {
        return
    }

    $destination = Join-Path $projectRoot $relative

    if ($_.PSIsContainer) {
        New-Item -ItemType Directory -Path $destination -Force | Out-Null
    }
    else {
        $destinationDir = Split-Path -Parent $destination
        if (-not (Test-Path -LiteralPath $destinationDir)) {
            New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
        }
        Copy-Item -LiteralPath $_.FullName -Destination $destination -Force
    }
}

[pscustomobject]@{
    ProjectPath = $projectRoot
    TemplateRoot = $templateRoot
    Scaffolded = @(
        ".vscode\tasks.json",
        ".vscode\extensions.json",
        "tia-rest.http",
        "tools\tia-rest-client\package.json",
        "tools\tia-rest-client\src\tiaRestClient.mjs",
        "tools\tia-rest-client\src\demo.mjs",
        "tools\tia-rest-client\README.md"
    )
} | ConvertTo-Json -Depth 4
