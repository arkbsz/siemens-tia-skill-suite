param(
    [string]$WorkspacePath = (Get-Location).Path,

    [string]$ServerExe = "D:\plc\_analysis\skill-sources\vscode-tiaportal-mcp\srv\net48\TiaMcpServer.exe",

    [string]$TiaPortalLocation = "C:\Program Files\Siemens\Automation\Portal V17"
)

$ErrorActionPreference = "Stop"

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
