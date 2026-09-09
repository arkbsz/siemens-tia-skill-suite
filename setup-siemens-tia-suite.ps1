param(
    [string]$ProjectPath = "",

    [string]$TargetRoot = (Join-Path $env:USERPROFILE ".codex\skills"),

    [switch]$SkipDependencyInstall,

    [switch]$InstallClaudeCode,

    [switch]$InstallQoder,

    [switch]$NoLaunch
)

$ErrorActionPreference = "Stop"
$packageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$installScript = Join-Path $packageRoot "install-skills.ps1"

function Resolve-CodexCommand {
    $resolved = Get-Command codex.exe -ErrorAction SilentlyContinue
    if (-not $resolved) { $resolved = Get-Command codex -ErrorAction SilentlyContinue }
    if ($resolved) { return $resolved.Source }
    if ($env:CODEX_CLI_PATH -and (Test-Path -LiteralPath $env:CODEX_CLI_PATH)) { return $env:CODEX_CLI_PATH }
    return ""
}

function Get-CodexVersion {
    param([string]$CodexPath)
    $text = (& $CodexPath --version 2>&1 | Out-String).Trim()
    $match = [regex]::Match($text, '(?<version>\d+\.\d+\.\d+)')
    if ($match.Success) { return [version]$match.Groups['version'].Value }
    return [version]'0.0.0'
}

function Resolve-AgentCommand {
    param([string[]]$Candidates)
    foreach ($candidate in $Candidates) {
        $resolved = Get-Command $candidate -ErrorAction SilentlyContinue
        if ($resolved) { return $resolved.Source }
    }
    return ""
}

function Get-DetectedAgentPlatforms {
    $items = @()
    $codex = Resolve-CodexCommand
    if ($codex) { $items += [pscustomobject]@{ id = "codex"; command = $codex } }
    $claude = Resolve-AgentCommand -Candidates @("claude.exe", "claude.cmd", "claude")
    if ($claude) { $items += [pscustomobject]@{ id = "claude-code"; command = $claude } }
    $trae = Resolve-AgentCommand -Candidates @("trae-cli.exe", "trae-cli.cmd", "trae-cli")
    if ($trae) { $items += [pscustomobject]@{ id = "trae-agent"; command = $trae } }
    $qoder = Resolve-AgentCommand -Candidates @("qodercli.exe", "qodercli.cmd", "qodercli")
    if ($qoder) { $items += [pscustomobject]@{ id = "qoder"; command = $qoder } }
    return @($items)
}

if (-not (Test-Path -LiteralPath $installScript)) {
    throw "Skill installer was not found: $installScript"
}

$runningConsoles = Get-CimInstance Win32_Process -Filter "Name='PLCDevConsole.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.ExecutablePath -and $_.ExecutablePath.StartsWith($TargetRoot, [StringComparison]::OrdinalIgnoreCase) }
foreach ($runningConsole in $runningConsoles) {
    Stop-Process -Id $runningConsole.ProcessId -Force -ErrorAction SilentlyContinue
}

$npm = Get-Command npm.cmd -ErrorAction SilentlyContinue
if (-not $npm) { $npm = Get-Command npm -ErrorAction SilentlyContinue }
if ($InstallClaudeCode) {
    if (-not $npm) { throw "Node.js/npm is required to install Claude Code." }
    & $npm.Source install --global @anthropic-ai/claude-code
    if ($LASTEXITCODE -ne 0) { throw "Claude Code installation failed." }
}
if ($InstallQoder) {
    if (-not $npm) { throw "Node.js/npm is required to install Qoder CLI." }
    & $npm.Source install --global @qoder-ai/qodercli
    if ($LASTEXITCODE -ne 0) { throw "Qoder CLI installation failed." }
}

$detectedPlatforms = @(Get-DetectedAgentPlatforms)
$codexPath = Resolve-CodexCommand
if ($detectedPlatforms.Count -eq 0 -and -not $SkipDependencyInstall) {
    if ($npm) {
        & $npm.Source install --global @openai/codex
        if ($LASTEXITCODE -ne 0) { throw "The official @openai/codex CLI installation failed." }
        $codexPath = Resolve-CodexCommand
        $detectedPlatforms = @(Get-DetectedAgentPlatforms)
    }
}
if ($detectedPlatforms.Count -eq 0) {
    throw "At least one AI platform CLI is required: Codex, Claude Code, Trae Agent, or Qoder."
}
$codexVersion = [version]'0.0.0'
if ($codexPath) { $codexVersion = Get-CodexVersion -CodexPath $codexPath }
if ($codexPath -and $codexVersion -lt [version]'0.153.4' -and -not $SkipDependencyInstall) {
    & $codexPath update
    if ($LASTEXITCODE -ne 0) { throw "Codex CLI is older than 0.153.4 and automatic update failed." }
    $codexPath = Resolve-CodexCommand
    $codexVersion = Get-CodexVersion -CodexPath $codexPath
}

$installOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installScript -TargetRoot $TargetRoot
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$installReport = ($installOutput | Out-String).Trim() | ConvertFrom-Json

$plcSkillRoot = Join-Path $TargetRoot "siemens-tia-plc-dev"
$buildScript = Join-Path $plcSkillRoot "scripts\build-plc-dev-console-exe.ps1"
$invokeScript = Join-Path $plcSkillRoot "scripts\invoke-siemens-plc-dev.ps1"
$profilesPath = Join-Path $plcSkillRoot "agents\siemens-agent-profiles.json"
$platformsPath = Join-Path $plcSkillRoot "agents\ai-platforms.json"
$routesPath = Join-Path $plcSkillRoot "agents\siemens-workflow-routes.json"
$buildOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $buildScript -Force
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$buildReport = ($buildOutput | Out-String).Trim() | ConvertFrom-Json

$loginOutput = "Codex is not installed; another configured platform will be used."
$loginReady = $false
if ($codexPath) {
    $loginStdoutPath = Join-Path $env:TEMP ("siemens-tia-codex-login-" + [guid]::NewGuid().ToString("N") + ".out")
    $loginStderrPath = Join-Path $env:TEMP ("siemens-tia-codex-login-" + [guid]::NewGuid().ToString("N") + ".err")
    $loginProcess = Start-Process -FilePath $codexPath -ArgumentList @("login", "status") -PassThru -Wait -WindowStyle Hidden -RedirectStandardOutput $loginStdoutPath -RedirectStandardError $loginStderrPath
    $loginOutput = @(
        if (Test-Path -LiteralPath $loginStdoutPath) { Get-Content -LiteralPath $loginStdoutPath -Raw }
        if (Test-Path -LiteralPath $loginStderrPath) { Get-Content -LiteralPath $loginStderrPath -Raw }
    ) -join [Environment]::NewLine
    $loginReady = ($loginProcess.ExitCode -eq 0)
    Remove-Item -LiteralPath $loginStdoutPath, $loginStderrPath -Force -ErrorAction SilentlyContinue
}
$probeScript = Join-Path $plcSkillRoot "scripts\probe-ai-platforms.ps1"
$platformReport = (& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $probeScript | Out-String).Trim() | ConvertFrom-Json
$readyPlatforms = @($platformReport.platforms | Where-Object { $_.installed -and $_.authState -ne "login-required" })
$tiaVersions = @(Get-ChildItem -LiteralPath "C:\Program Files\Siemens\Automation" -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^Portal V(16|17|18|19|20|21)$' } |
    Select-Object -ExpandProperty Name)

$runtimeRoot = Join-Path $env:USERPROFILE ".codex\siemens-tia-suite"
New-Item -ItemType Directory -Path $runtimeRoot -Force | Out-Null
$runtimeConfigPath = Join-Path $runtimeRoot "agent-runtime.json"
$runtimeConfig = [pscustomobject]@{
    schemaVersion = 2
    configuredAt = (Get-Date).ToString("o")
    codexPath = $codexPath
    codexVersion = $codexVersion.ToString()
    codexLoginReady = $loginReady
    skillsRoot = $TargetRoot
    plcSkillRoot = $plcSkillRoot
    agentProfiles = $profilesPath
    aiPlatforms = $platformsPath
    workflowRoutes = $routesPath
    detectedAgentPlatforms = $platformReport.platforms
    consoleExe = $buildReport.ExePath
    supportedTiaVersions = "V16-V21"
    installedTiaVersions = $tiaVersions
}
$runtimeConfig | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $runtimeConfigPath -Encoding UTF8

$processId = $null
if (-not $NoLaunch) {
    $arguments = @("--invoke", $invokeScript)
    if ($ProjectPath) { $arguments += @("--project", $ProjectPath) }
    $process = Start-Process -FilePath $buildReport.ExePath -ArgumentList $arguments -PassThru -WindowStyle Normal
    $processId = $process.Id
}

[pscustomobject]@{
    Status = if ($readyPlatforms.Count -gt 0) { "Ready" } else { "AgentLoginOrInstallRequired" }
    CodexPath = $codexPath
    CodexVersion = $codexVersion.ToString()
    CodexLogin = ($loginOutput | Out-String).Trim()
    InstalledTiaVersions = $tiaVersions
    RuntimeConfig = $runtimeConfigPath
    SkillBackup = $installReport.BackupRoot
    AgentProfiles = $profilesPath
    AgentPlatforms = $platformReport.platforms
    WorkflowRoutes = $routesPath
    ConsoleExe = $buildReport.ExePath
    ProcessId = $processId
} | ConvertTo-Json -Depth 6
