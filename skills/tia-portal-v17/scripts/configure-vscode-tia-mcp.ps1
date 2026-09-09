param(
    [string]$WorkspacePath = (Get-Location).Path,

    [string]$ServerExe = "C:\path\to\TiaMcpServer.exe",

    [string]$TiaPortalLocation,

    [string]$PreferredVersion
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "resolve-tia-portal.ps1")

if (-not $TiaPortalLocation) {
    $locationHint = Get-TiaLocationHint `
        -ProjectPath $null `
        -PreferredVersion $PreferredVersion `
        -ExplicitLocation $null `
        -EnvironmentLocation $env:TiaPortalLocation
    $publicApiHint = Get-TiaPublicApiHint `
        -ProjectPath $null `
        -PreferredVersion $PreferredVersion `
        -ExplicitPublicApiPath $null `
        -EnvironmentPublicApiPath $env:TiaPortalPublicApiPath
    $resolved = Resolve-TiaPortalEnvironment `
        -PreferredVersion $(if ($PreferredVersion) { $PreferredVersion } else { $env:CODEX_TIA_PREFERRED_VERSION }) `
        -TiaPortalLocation $locationHint `
        -TiaPortalPublicApiPath $publicApiHint
    $TiaPortalLocation = $resolved.TiaRoot
}

if (-not (Test-Path -LiteralPath $ServerExe)) {
    throw "TiaMcpServer.exe not found: $ServerExe"
}

if (-not (Test-Path -LiteralPath $TiaPortalLocation)) {
    throw "TIA Portal location not found: $TiaPortalLocation"
}

$vscodeDir = Join-Path $WorkspacePath ".vscode"
$configPath = Join-Path $vscodeDir "mcp.json"
New-Item -ItemType Directory -Path $vscodeDir -Force | Out-Null

$config = [ordered]@{
    servers = [ordered]@{
        "vscode-tiaportal-mcp" = [ordered]@{
            command = $ServerExe
            args = @()
            env = [ordered]@{
                TiaPortalLocation = $TiaPortalLocation
            }
        }
    }
}

$config | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $configPath -Encoding UTF8

[pscustomobject]@{
    Config = $configPath
    Server = $ServerExe
    TiaPortalLocation = $TiaPortalLocation
} | Format-List
