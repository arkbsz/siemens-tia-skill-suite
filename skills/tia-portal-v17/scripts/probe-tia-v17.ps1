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
    TiaRootExists = Test-Path -LiteralPath $tiaRoot
    PortalExeExists = Test-Path -LiteralPath $portalExe
    PublicApiExists = Test-Path -LiteralPath $publicApiRoot
    SiemensEngineeringDllExists = Test-Path -LiteralPath $engineeringDll
    TiaPortalLocationEnv = [Environment]::GetEnvironmentVariable("TiaPortalLocation", "User")
    ConfiguredInSiemensTiaOpennessGroup = $configuredInOpennessGroup
    ActiveInCurrentLogonToken = [bool]($userGroups -match "Siemens TIA Openness")
    RunningPortalProcesses = @(Get-Process | Where-Object { $_.ProcessName -like "Siemens.Automation.Portal" } | Select-Object -ExpandProperty Id)
    ProjectInfo = $projectInfo
} | ConvertTo-Json -Depth 5
