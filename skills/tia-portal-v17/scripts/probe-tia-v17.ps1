param(
    [string]$ProjectPath
)

$ErrorActionPreference = "Stop"

$tiaRoot = "C:\Program Files\Siemens\Automation\Portal V17"
$publicApiRoot = Join-Path $tiaRoot "PublicAPI\V17"
$engineeringDll = Join-Path $publicApiRoot "Siemens.Engineering.dll"
$portalExe = Join-Path $tiaRoot "Bin\Siemens.Automation.Portal.exe"

$userGroups = @()
try {
    $userGroups = (whoami /groups) 2>$null
}
catch {
}

$currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$configuredInOpennessGroup = $false
try {
    $configuredInOpennessGroup = [bool](Get-LocalGroupMember -Group "Siemens TIA Openness" -ErrorAction Stop | Where-Object {
        $_.Name -ieq $currentIdentity -or $_.Name -ieq ($env:COMPUTERNAME + "\" + $env:USERNAME) -or $_.Name -ieq $env:USERNAME
    })
}
catch {
}

$tiaRootExists = Test-Path -LiteralPath $tiaRoot
$portalExeExists = Test-Path -LiteralPath $portalExe
$publicApiExists = Test-Path -LiteralPath $publicApiRoot
$engineeringDllExists = Test-Path -LiteralPath $engineeringDll
$activeInCurrentLogonToken = [bool]($userGroups -match "Siemens TIA Openness")
$runningPortalProcesses = @(Get-Process | Where-Object { $_.ProcessName -like "Siemens.Automation.Portal" } | Select-Object -ExpandProperty Id)
$readinessIssues = [System.Collections.Generic.List[string]]::new()

if (-not $tiaRootExists) {
    $readinessIssues.Add("TIA Portal V17 root not found: $tiaRoot")
}
if (-not $portalExeExists) {
    $readinessIssues.Add("TIA Portal executable not found: $portalExe")
}
if (-not $publicApiExists) {
    $readinessIssues.Add("TIA Portal PublicAPI folder not found: $publicApiRoot")
}
if (-not $engineeringDllExists) {
    $readinessIssues.Add("Siemens.Engineering.dll not found: $engineeringDll")
}
if (-not $configuredInOpennessGroup) {
    $readinessIssues.Add("Current Windows user is not configured in the 'Siemens TIA Openness' local group.")
}
elseif (-not $activeInCurrentLogonToken) {
    $readinessIssues.Add("Current Windows logon session does not yet contain the 'Siemens TIA Openness' group. Fully sign out of Windows and sign in again before using Openness.")
}

$recommendedNextStep = if (-not $configuredInOpennessGroup) {
    "Add the current Windows user to the 'Siemens TIA Openness' local group, then fully sign out of Windows and sign in again."
}
elseif (-not $activeInCurrentLogonToken) {
    "The user is already configured in the Openness group, but the current logon token is stale. Fully sign out of Windows and sign in again, then rerun 'probe' or 'doctor' before starting clone/import/compile."
}
elseif (-not $tiaRootExists -or -not $portalExeExists -or -not $publicApiExists -or -not $engineeringDllExists) {
    "Repair or confirm the local TIA Portal V17 installation before running Openness automation."
}
else {
    "Openness prerequisites look ready. Start with list-plcs or export-blocks, then continue with import/compile on a backup clone."
}

[bool]$readyForOpennessSession = (
    $tiaRootExists -and
    $portalExeExists -and
    $publicApiExists -and
    $engineeringDllExists -and
    $configuredInOpennessGroup -and
    $activeInCurrentLogonToken
)

$projectInfo = $null
if ($ProjectPath -and (Test-Path -LiteralPath $ProjectPath)) {
    $item = Get-Item -LiteralPath $ProjectPath
    $projectDir = if ($item.PSIsContainer) { $item.FullName } else { $item.Directory.FullName }
    $projectInfo = [pscustomobject]@{
        Path = $projectDir
        Ap17Files = @(Get-ChildItem -LiteralPath $projectDir -Filter *.ap17 -Force -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
        HasSystemFolder = Test-Path -LiteralPath (Join-Path $projectDir "System")
        HasXRefDb = Test-Path -LiteralPath (Join-Path $projectDir "XRef\XRef.db")
        HasVciDb = Test-Path -LiteralPath (Join-Path $projectDir "Vci\Vci.db")
    }
}

[pscustomobject]@{
    TiaRootExists = $tiaRootExists
    PortalExeExists = $portalExeExists
    PublicApiExists = $publicApiExists
    SiemensEngineeringDllExists = $engineeringDllExists
    TiaPortalLocationEnv = [Environment]::GetEnvironmentVariable("TiaPortalLocation", "User")
    ConfiguredInSiemensTiaOpennessGroup = $configuredInOpennessGroup
    ActiveInCurrentLogonToken = $activeInCurrentLogonToken
    ReadyForOpennessSession = $readyForOpennessSession
    ReadinessIssues = @($readinessIssues)
    RecommendedNextStep = $recommendedNextStep
    RunningPortalProcesses = $runningPortalProcesses
    ProjectInfo = $projectInfo
} | ConvertTo-Json -Depth 5
