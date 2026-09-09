param(
    [string]$WorkflowConfigPath = "",
    [string]$PlatformsPath = ""
)

$ErrorActionPreference = "Stop"
$skillRoot = Split-Path -Parent $PSScriptRoot
if (-not $PlatformsPath) { $PlatformsPath = Join-Path $skillRoot "agents\ai-platforms.json" }
$catalog = Get-Content -LiteralPath $PlatformsPath -Raw -Encoding UTF8 | ConvertFrom-Json
$config = $null
if ($WorkflowConfigPath -and (Test-Path -LiteralPath $WorkflowConfigPath -PathType Leaf)) {
    $config = Get-Content -LiteralPath $WorkflowConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Get-PropertyValue {
    param($Object, [string]$Name, $Fallback = $null)
    if ($null -eq $Object) { return $Fallback }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) { return $Fallback }
    return $property.Value
}

function Resolve-Candidate {
    param([string]$Value)
    if (-not $Value) { return "" }
    $expanded = [Environment]::ExpandEnvironmentVariables($Value.Trim().Trim('"'))
    if (Test-Path -LiteralPath $expanded -PathType Leaf) { return (Get-Item -LiteralPath $expanded).FullName }
    $command = Get-Command $expanded -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    return ""
}

$results = foreach ($platform in $catalog.platforms) {
    $configKey = switch ([string]$platform.id) {
        "codex" { "codexCommand" }
        "claude-code" { "claudeCommand" }
        "trae-agent" { "traeCommand" }
        "qoder" { "qoderCommand" }
    }
    $platformConfig = Get-PropertyValue -Object $config -Name "platform"
    $override = [string](Get-PropertyValue -Object $platformConfig -Name $configKey -Fallback "")
    $commandPath = Resolve-Candidate -Value $override
    if (-not $commandPath) {
        $envValue = [Environment]::GetEnvironmentVariable([string]$platform.environmentOverride)
        $commandPath = Resolve-Candidate -Value $envValue
    }
    if (-not $commandPath) {
        foreach ($candidate in @($platform.commandCandidates)) {
            $commandPath = Resolve-Candidate -Value ([string]$candidate)
            if ($commandPath) { break }
        }
    }
    if (-not $commandPath -and [string]$platform.id -eq "codex") {
        $binRoot = Join-Path $env:LOCALAPPDATA "OpenAI\Codex\bin"
        if (Test-Path -LiteralPath $binRoot) {
            $commandPath = Get-ChildItem -LiteralPath $binRoot -Filter codex.exe -File -Recurse -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
        }
    }

    $version = ""
    $authState = "not-installed"
    $authDetail = ""
    if ($commandPath) {
        try { $version = ((& $commandPath --version 2>&1 | Select-Object -First 1) | Out-String).Trim() } catch { $version = $_.Exception.Message }
        $authState = "unknown"
        if ([string]$platform.id -eq "codex") {
            try {
                $previousErrorPreference = $ErrorActionPreference
                $ErrorActionPreference = "Continue"
                $authLines = @(& $commandPath login status 2>&1)
                $authExitCode = $LASTEXITCODE
                $ErrorActionPreference = $previousErrorPreference
                $authDetail = (@($authLines | ForEach-Object { [string]$_ }) -join [Environment]::NewLine).Trim()
                if ($authExitCode -eq 0 -or $authDetail.ToLowerInvariant().Contains("logged in") -or $authDetail.ToLowerInvariant().Contains("authenticated")) { $authState = "ready" } else { $authState = "login-required" }
            }
            catch { $ErrorActionPreference = "Stop"; $authState = "login-required"; $authDetail = $_.Exception.Message }
        }
        elseif ([string]$platform.id -eq "claude-code") {
            try {
                $previousErrorPreference = $ErrorActionPreference
                $ErrorActionPreference = "Continue"
                $authLines = @(& $commandPath auth status 2>&1)
                $authExitCode = $LASTEXITCODE
                $ErrorActionPreference = $previousErrorPreference
                $authDetail = (@($authLines | ForEach-Object { [string]$_ }) -join [Environment]::NewLine).Trim()
                if ($authExitCode -eq 0 -or $authDetail.ToLowerInvariant().Contains("logged in") -or $authDetail.ToLowerInvariant().Contains("authenticated")) { $authState = "ready" } else { $authState = "login-required" }
            }
            catch { $ErrorActionPreference = "Stop"; $authState = "login-required"; $authDetail = $_.Exception.Message }
        }
    }
    [pscustomobject]@{
        id = [string]$platform.id
        name = [string]$platform.name
        installed = [bool]$commandPath
        command = [string]$commandPath
        version = $version
        authState = $authState
        authDetail = $authDetail
        supportsSessions = [bool]$platform.supportsSessions
        supportsImages = [bool]$platform.supportsImages
        installHint = [string]$platform.installHint
    }
}

[pscustomobject]@{
    schemaVersion = 1
    checkedAt = (Get-Date).ToString("o")
    platforms = @($results)
} | ConvertTo-Json -Depth 8
