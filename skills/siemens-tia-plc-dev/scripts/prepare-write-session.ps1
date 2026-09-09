param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    [string]$BaseUrl = "http://127.0.0.1:8765",

    [int]$StartupTimeoutSeconds = 120,

    [switch]$Ui,

    [switch]$SkipBridgeStart
)

$ErrorActionPreference = "Stop"

function Test-HasNonAscii {
    param([string]$Value)

    foreach ($char in $Value.ToCharArray()) {
        if ([int][char]$char -gt 127) {
            return $true
        }
    }
    return $false
}

function New-AsciiProjectAlias {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResolvedProjectPath
    )

    $projectItem = Get-Item -LiteralPath $ResolvedProjectPath
    $projectDir = if ($projectItem.PSIsContainer) { $projectItem.FullName } else { $projectItem.Directory.FullName }
    $projectLeaf = if ($projectItem.PSIsContainer) { $null } else { $projectItem.Name }

    $hashBytes = [System.Security.Cryptography.MD5]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($projectDir))
    $hash = ([System.BitConverter]::ToString($hashBytes)).Replace("-", "").Substring(0, 12).ToLowerInvariant()
    $aliasRoot = Join-Path $PSScriptRoot ".session-cache\ascii-paths"
    $aliasDir = Join-Path $aliasRoot ("project-" + $hash)

    New-Item -ItemType Directory -Path $aliasRoot -Force | Out-Null
    if (-not (Test-Path -LiteralPath $aliasDir)) {
        New-Item -ItemType Junction -Path $aliasDir -Target $projectDir | Out-Null
    }

    if ($projectLeaf) {
        return Join-Path $aliasDir $projectLeaf
    }

    return $aliasDir
}

function Test-BridgeHealth {
    param([string]$Url)

    try {
        $response = Invoke-RestMethod -Method Get -Uri ($Url.TrimEnd("/") + "/health") -TimeoutSec 5
        return [pscustomobject]@{
            Healthy = $true
            Response = $response
        }
    }
    catch {
        return [pscustomobject]@{
            Healthy = $false
            Response = $null
        }
    }
}

function Wait-BridgeReady {
    param(
        [string]$Url,
        [int]$TimeoutSeconds
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $health = Test-BridgeHealth -Url $Url
        if ($health.Healthy) {
            return $health
        }
        Start-Sleep -Milliseconds 1000
    } while ((Get-Date) -lt $deadline)

    throw "TIA REST bridge did not become ready within $TimeoutSeconds seconds at $Url"
}

$resolvedProject = (Get-Item -LiteralPath $ProjectPath).FullName
$bridgeProjectPath = if (Test-HasNonAscii -Value $resolvedProject) {
    New-AsciiProjectAlias -ResolvedProjectPath $resolvedProject
}
else {
    $resolvedProject
}
$startScript = Join-Path $PSScriptRoot "start-tia-rest-bridge.ps1"
if (-not (Test-Path -LiteralPath $startScript)) {
    throw "Missing dependency script: $startScript"
}

$bridgeStarted = $false
$health = Test-BridgeHealth -Url $BaseUrl
if (-not $health.Healthy) {
    if ($SkipBridgeStart) {
        throw "TIA REST bridge is not reachable at $BaseUrl and -SkipBridgeStart was used."
    }

    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $startScript -Background | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to start TIA REST bridge."
    }

    $bridgeStarted = $true
    $health = Wait-BridgeReady -Url $BaseUrl -TimeoutSeconds $StartupTimeoutSeconds
}

$sessionsBefore = Invoke-RestMethod -Method Get -Uri ($BaseUrl.TrimEnd("/") + "/api/v1/sessions") -TimeoutSec 15
$openBody = @{
    projectPath = $bridgeProjectPath
    ui = [bool]$Ui
} | ConvertTo-Json
$openResponse = Invoke-RestMethod -Method Post -Uri ($BaseUrl.TrimEnd("/") + "/api/v1/sessions/open") -ContentType "application/json" -Body $openBody -TimeoutSec $StartupTimeoutSeconds
$sessionsAfter = Invoke-RestMethod -Method Get -Uri ($BaseUrl.TrimEnd("/") + "/api/v1/sessions") -TimeoutSec 15

[pscustomobject]@{
    BaseUrl = $BaseUrl
    ProjectPath = $resolvedProject
    BridgeProjectPath = $bridgeProjectPath
    UsedAsciiAlias = ($bridgeProjectPath -ne $resolvedProject)
    BridgeStarted = $bridgeStarted
    SessionsBefore = $sessionsBefore
    SessionOpen = $openResponse
    SessionsAfter = $sessionsAfter
    Notes = @(
        "Use useSession=true in REST calls after this step for lower-latency imports and exports.",
        "If BridgeProjectPath differs from ProjectPath, use BridgeProjectPath in later REST requests for this session.",
        "For XML files under the project directory, build REST file paths from BridgeProjectPath when non-ASCII paths are problematic.",
        "Do not open the same project from another Openness process while this session is held."
    )
} | ConvertTo-Json -Depth 8
