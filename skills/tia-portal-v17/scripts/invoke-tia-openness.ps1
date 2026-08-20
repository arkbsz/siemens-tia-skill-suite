param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ToolArgs
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$source = Join-Path $scriptDir "TiaPlcTool.cs"
$buildDir = Join-Path $scriptDir "bin"
$exe = Join-Path $buildDir "TiaPlcTool.exe"

$tiaRoot = if ($env:TiaPortalLocation) {
    $env:TiaPortalLocation
} else {
    "C:\Program Files\Siemens\Automation\Portal V17"
}

$engineeringDll = Join-Path $tiaRoot "PublicAPI\V17\Siemens.Engineering.dll"
$hmiDll = Join-Path $tiaRoot "PublicAPI\V17\Siemens.Engineering.Hmi.dll"
$csc = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"

if (-not (Test-Path -LiteralPath $engineeringDll)) {
    throw "Siemens.Engineering.dll not found: $engineeringDll"
}
if (-not (Test-Path -LiteralPath $csc)) {
    throw ".NET Framework C# compiler not found: $csc"
}

New-Item -ItemType Directory -Path $buildDir -Force | Out-Null

foreach ($dll in @($engineeringDll, $hmiDll)) {
    if (Test-Path -LiteralPath $dll) {
        $targetDll = Join-Path $buildDir (Split-Path -Leaf $dll)
        if ((-not (Test-Path -LiteralPath $targetDll)) -or
            ((Get-Item -LiteralPath $dll).LastWriteTimeUtc -gt (Get-Item -LiteralPath $targetDll).LastWriteTimeUtc)) {
            Copy-Item -LiteralPath $dll -Destination $targetDll -Force
        }
    }
}

$needsBuild = -not (Test-Path -LiteralPath $exe)
if (-not $needsBuild) {
    $needsBuild = (Get-Item -LiteralPath $source).LastWriteTimeUtc -gt (Get-Item -LiteralPath $exe).LastWriteTimeUtc
}

if ($needsBuild) {
    & $csc `
        /nologo `
        /platform:x64 `
        /target:exe `
        "/out:$exe" `
        "/reference:$engineeringDll" `
        "/reference:System.Core.dll" `
        $source

    if ($LASTEXITCODE -ne 0) {
        throw "TiaPlcTool build failed with exit code $LASTEXITCODE"
    }
}

& $exe @ToolArgs
exit $LASTEXITCODE
