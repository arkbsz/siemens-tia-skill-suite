param(
    [string]$ProjectPath,

    [string]$PreferredVersion,

    [string]$TiaPortalLocation,

    [string]$TiaPortalPublicApiPath
)

$argsList = @()
if ($PSBoundParameters.ContainsKey("ProjectPath")) {
    $argsList += @("-ProjectPath", $ProjectPath)
}
if ($PSBoundParameters.ContainsKey("PreferredVersion")) {
    $argsList += @("-PreferredVersion", $PreferredVersion)
}
if ($PSBoundParameters.ContainsKey("TiaPortalLocation")) {
    $argsList += @("-TiaPortalLocation", $TiaPortalLocation)
}
if ($PSBoundParameters.ContainsKey("TiaPortalPublicApiPath")) {
    $argsList += @("-TiaPortalPublicApiPath", $TiaPortalPublicApiPath)
}

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "probe-tia-v17.ps1") @argsList

exit $LASTEXITCODE
