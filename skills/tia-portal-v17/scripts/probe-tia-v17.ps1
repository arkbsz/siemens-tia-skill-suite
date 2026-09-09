param(
    [string]$ProjectPath,

    [string]$PreferredVersion,

    [string]$TiaPortalLocation,

    [string]$TiaPortalPublicApiPath
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "resolve-tia-portal.ps1")

$locationHint = Get-TiaLocationHint `
    -ProjectPath $ProjectPath `
    -PreferredVersion $PreferredVersion `
    -ExplicitLocation $TiaPortalLocation `
    -EnvironmentLocation $env:TiaPortalLocation
$publicApiHint = Get-TiaPublicApiHint `
    -ProjectPath $ProjectPath `
    -PreferredVersion $PreferredVersion `
    -ExplicitPublicApiPath $TiaPortalPublicApiPath `
    -EnvironmentPublicApiPath $env:TiaPortalPublicApiPath

$resolved = Resolve-TiaPortalEnvironment `
    -ProjectPath $ProjectPath `
    -PreferredVersion $PreferredVersion `
    -TiaPortalLocation $locationHint `
    -TiaPortalPublicApiPath $publicApiHint

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

$activeInCurrentLogonToken = [bool]($userGroups -match "Siemens TIA Openness")
$runningPortalProcesses = @(Get-Process | Where-Object { $_.ProcessName -like "Siemens.Automation.Portal" } | Select-Object -ExpandProperty Id)
$readinessIssues = [System.Collections.Generic.List[string]]::new()

if (-not $resolved.TiaRootExists) {
    $readinessIssues.Add("TIA Portal root not found for $($resolved.VersionTag): $($resolved.TiaRoot)")
}
if (-not $resolved.PortalExeExists) {
    $readinessIssues.Add("TIA Portal executable not found: $($resolved.PortalExePath)")
}
if (-not $resolved.PublicApiExists) {
    $readinessIssues.Add("TIA Portal PublicAPI folder not found: $($resolved.PublicApiRoot)")
}
if (-not $resolved.EngineeringAssemblyExists) {
    $readinessIssues.Add("Primary Openness assembly not found: $($resolved.EngineeringAssemblyPath)")
}
if ($resolved.ExistingPrimaryReferencePaths.Count -lt $resolved.PrimaryReferencePaths.Count) {
    $missingRefs = @($resolved.PrimaryReferencePaths | Where-Object { -not (Test-Path -LiteralPath $_) })
    if ($missingRefs.Count -gt 0) {
        $readinessIssues.Add("One or more compile-time Openness references are missing: $($missingRefs -join ', ')")
    }
}
if (-not $configuredInOpennessGroup) {
    $readinessIssues.Add("Current Windows user is not configured in the 'Siemens TIA Openness' local group.")
}
elseif (-not $activeInCurrentLogonToken) {
    $readinessIssues.Add("Current Windows logon session does not yet contain the 'Siemens TIA Openness' group. Fully sign out of Windows and sign in again before using Openness.")
}

$projectInfo = $null
if ($ProjectPath -and (Test-Path -LiteralPath $ProjectPath)) {
    $item = Get-Item -LiteralPath $ProjectPath
    $projectDir = if ($item.PSIsContainer) { $item.FullName } else { $item.Directory.FullName }
    $projectFiles = @(Get-TiaProjectFiles -ProjectPath $projectDir)
    $projectVersion = Get-TiaProjectVersion -ProjectPath $projectDir

    if ($projectVersion -and $projectVersion -ne $resolved.VersionMajor) {
        $readinessIssues.Add("Project appears to be V$projectVersion but the resolved local Openness environment is $($resolved.VersionTag). Use a matching installation or intentionally migrate the project first.")
    }

    $projectInfo = [pscustomobject]@{
        Path = $projectDir
        ProjectFiles = @($projectFiles | Select-Object -ExpandProperty Name)
        ProjectVersionTag = if ($projectVersion) { "V$projectVersion" } else { $null }
        HasSystemFolder = Test-Path -LiteralPath (Join-Path $projectDir "System")
        HasXRefDb = Test-Path -LiteralPath (Join-Path $projectDir "XRef\XRef.db")
        HasVciDb = Test-Path -LiteralPath (Join-Path $projectDir "Vci\Vci.db")
    }
}

$recommendedNextStep = if (-not $configuredInOpennessGroup) {
    "Add the current Windows user to the 'Siemens TIA Openness' local group, then fully sign out of Windows and sign in again."
}
elseif (-not $activeInCurrentLogonToken) {
    "The user is already configured in the Openness group, but the current logon token is stale. Fully sign out of Windows and sign in again, then rerun 'probe' or 'doctor' before starting clone/import/compile."
}
elseif ($projectInfo -and $projectInfo.ProjectVersionTag -and $projectInfo.ProjectVersionTag -ne $resolved.VersionTag) {
    "Install or point the toolchain to a matching TIA Portal $($projectInfo.ProjectVersionTag) environment before opening this project, or intentionally migrate the project in TIA first."
}
elseif (-not $resolved.TiaRootExists -or -not $resolved.PortalExeExists -or -not $resolved.PublicApiExists -or -not $resolved.EngineeringAssemblyExists) {
    "Repair or confirm the local TIA Portal $($resolved.VersionTag) installation before running Openness automation."
}
else {
    "Openness prerequisites look ready. Start with list-plcs or export-blocks, then continue with import/compile on a backup clone."
}

[bool]$readyForOpennessSession = (
    $resolved.TiaRootExists -and
    $resolved.PortalExeExists -and
    $resolved.PublicApiExists -and
    $resolved.EngineeringAssemblyExists -and
    ($resolved.ExistingPrimaryReferencePaths.Count -ge $resolved.PrimaryReferencePaths.Count) -and
    $configuredInOpennessGroup -and
    $activeInCurrentLogonToken -and
    (
        -not $projectInfo -or
        -not $projectInfo.ProjectVersionTag -or
        $projectInfo.ProjectVersionTag -eq $resolved.VersionTag
    )
)

[pscustomobject]@{
    DetectedVersion = $resolved.VersionTag
    DetectedVersionMajor = $resolved.VersionMajor
    TiaRootExists = $resolved.TiaRootExists
    PortalExeExists = $resolved.PortalExeExists
    PublicApiExists = $resolved.PublicApiExists
    SiemensEngineeringDllExists = $resolved.EngineeringAssemblyExists
    TiaPortalLocationEnv = [Environment]::GetEnvironmentVariable("TiaPortalLocation", "User")
    TiaPortalPublicApiPathEnv = [Environment]::GetEnvironmentVariable("TiaPortalPublicApiPath", "User")
    ConfiguredInSiemensTiaOpennessGroup = $configuredInOpennessGroup
    ActiveInCurrentLogonToken = $activeInCurrentLogonToken
    ReadyForOpennessSession = $readyForOpennessSession
    ReadinessIssues = @($readinessIssues)
    RecommendedNextStep = $recommendedNextStep
    RunningPortalProcesses = $runningPortalProcesses
    ResolvedEnvironment = $resolved
    ProjectInfo = $projectInfo
} | ConvertTo-Json -Depth 8
