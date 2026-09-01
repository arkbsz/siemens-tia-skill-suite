param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ToolArgs
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$source = Join-Path $scriptDir "TiaPlcTool.cs"
$buildDir = Join-Path $scriptDir "bin"
$exe = Join-Path $buildDir "TiaPlcTool.exe"
$probeScript = Join-Path $scriptDir "probe-tia-v17.ps1"

$tiaRoot = if ($env:TiaPortalLocation) {
    $env:TiaPortalLocation
} else {
    "C:\Program Files\Siemens\Automation\Portal V17"
}

$engineeringDll = Join-Path $tiaRoot "PublicAPI\V17\Siemens.Engineering.dll"
$hmiDll = Join-Path $tiaRoot "PublicAPI\V17\Siemens.Engineering.Hmi.dll"
$csc = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"

function Get-ToolOptionValue {
    param(
        [string[]]$Arguments,
        [string]$Name
    )

    for ($i = 0; $i -lt ($Arguments.Count - 1); $i++) {
        if ($Arguments[$i] -ieq $Name) {
            return $Arguments[$i + 1]
        }
    }

    return $null
}

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

$commandName = if ($ToolArgs.Count -gt 0) { $ToolArgs[0].ToLowerInvariant() } else { "help" }
if ($commandName -ne "help") {
    if (-not (Test-Path -LiteralPath $probeScript)) {
        throw "Probe script not found: $probeScript"
    }

    $projectForProbe = Get-ToolOptionValue -Arguments $ToolArgs -Name "--project"
    $probeArgs = @()
    if ($projectForProbe) {
        $probeArgs += @("-ProjectPath", $projectForProbe)
    }

    $probeOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $probeScript @probeArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "TIA Openness preflight probe failed with exit code $LASTEXITCODE.`n$($probeOutput | Out-String)"
    }

    $probeText = ($probeOutput | Out-String).Trim()
    try {
        $probe = $probeText | ConvertFrom-Json
    }
    catch {
        throw "TIA Openness preflight probe returned unreadable JSON.`n$probeText"
    }

    if (-not [bool]$probe.ReadyForOpennessSession) {
        $issues = @($probe.ReadinessIssues | Where-Object { $_ })
        if ($issues.Count -eq 0) {
            $issues = @("Unknown readiness problem.")
        }

        $issueText = ($issues | ForEach-Object { "- $_" }) -join [Environment]::NewLine
        Write-Error ("TIA Openness preflight failed.`n{0}`nRecommended next step: {1}" -f $issueText, $probe.RecommendedNextStep)
        exit 2
    }
}

& $exe @ToolArgs
exit $LASTEXITCODE
