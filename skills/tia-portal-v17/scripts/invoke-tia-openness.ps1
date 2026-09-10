param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ToolArgs
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$source = Join-Path $scriptDir "TiaPlcTool.cs"
$buildDir = Join-Path $scriptDir "bin"
$exe = Join-Path $buildDir "TiaPlcTool.exe"
$buildMetadataPath = Join-Path $buildDir "TiaPlcTool.build.json"
$probeScript = Join-Path $scriptDir "probe-tia-v17.ps1"

$csc = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"

. (Join-Path $scriptDir "resolve-tia-portal.ps1")

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

$commandName = if ($ToolArgs.Count -gt 0) { $ToolArgs[0].ToLowerInvariant() } else { "help" }

function Show-Help {
    @"
TIA Portal V16-V21 Openness helper
Commands:
  help
  list-plcs --project <projectDir|ap16..ap21>
  list-blocks --project <projectDir|ap16..ap21> [--plc <name>]
  list-hmi --project <projectDir|ap16..ap21> [--hmi <name>]
  read-hmi --project <projectDir|ap16..ap21> [--hmi <name>] [--output <dir>] [--no-export]
  import-hmi --project <projectDir|ap16..ap21> --input <xml|dir> [--hmi <name>] [--kind auto|screen|tagtable|connection] [--apply] [--no-save]
  apply-hmi-manifest --project <projectDir|ap16..ap21> [--hmi <name>] [--tag-csv <csv>] [--alarm-csv <csv>] [--screen-csv <csv>] [--apply]
  export-blocks --project <projectDir|ap16..ap21> [--plc <name>] [--block <name>] [--language LAD|FBD|SCL] [--output <dir>]
  import-blocks --project <projectDir|ap16..ap21> --input <xml|dir> [--plc <name>] [--group <path>] [--apply] [--no-save]
  import-sources --project <projectDir|ap16..ap21> [--plc <name>] --source-dir <dir> [--compile] [--save]
  compile-plc --project <projectDir|ap16..ap21> [--plc <name>] [--save]

Notes:
  - This wrapper builds and runs a local Openness helper when the required Siemens assemblies are available.
  - If help is all you need, you do not need a complete TIA Openness installation.
  - If live commands fail with a missing PublicAPI assembly, repair the local TIA installation or switch to source-only XML/SCL workflows.
"@
}

if ($commandName -eq "help" -or $commandName -eq "--help" -or $commandName -eq "-h") {
    Show-Help
    exit 0
}

if (-not (Test-Path -LiteralPath $csc)) {
    throw ".NET Framework C# compiler not found: $csc"
}

New-Item -ItemType Directory -Path $buildDir -Force | Out-Null

$projectForProbe = Get-ToolOptionValue -Arguments $ToolArgs -Name "--project"
$preferredVersionHint = $env:CODEX_TIA_PREFERRED_VERSION
$locationHint = Get-TiaLocationHint `
    -ProjectPath $projectForProbe `
    -PreferredVersion $preferredVersionHint `
    -ExplicitLocation $null `
    -EnvironmentLocation $env:TiaPortalLocation
$publicApiHint = Get-TiaPublicApiHint `
    -ProjectPath $projectForProbe `
    -PreferredVersion $preferredVersionHint `
    -ExplicitPublicApiPath $null `
    -EnvironmentPublicApiPath $env:TiaPortalPublicApiPath
$resolved = Resolve-TiaPortalEnvironment `
    -ProjectPath $projectForProbe `
    -PreferredVersion $preferredVersionHint `
    -TiaPortalLocation $locationHint `
    -TiaPortalPublicApiPath $publicApiHint

if (-not $resolved.EngineeringAssemblyExists) {
    throw "Primary TIA Openness assembly not found for $($resolved.VersionTag): $($resolved.EngineeringAssemblyPath)"
}
if ($resolved.ExistingPrimaryReferencePaths.Count -lt $resolved.PrimaryReferencePaths.Count) {
    $missingReferences = @($resolved.PrimaryReferencePaths | Where-Object { -not (Test-Path -LiteralPath $_) })
    throw "Required TIA Openness compile references are missing for $($resolved.VersionTag): $($missingReferences -join ', ')"
}

$runtimeAssemblies = @(
    Get-ChildItem -LiteralPath $resolved.PublicApiRoot -Filter "Siemens.Engineering*.dll" -File -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty FullName
)

foreach ($dll in $runtimeAssemblies) {
    $targetDll = Join-Path $buildDir (Split-Path -Leaf $dll)
    if ((-not (Test-Path -LiteralPath $targetDll)) -or
        ((Get-Item -LiteralPath $dll).LastWriteTimeUtc -gt (Get-Item -LiteralPath $targetDll).LastWriteTimeUtc)) {
        Copy-Item -LiteralPath $dll -Destination $targetDll -Force
    }
}

$buildFingerprint = [ordered]@{
    VersionTag = $resolved.VersionTag
    PublicApiRoot = $resolved.PublicApiRoot
    ReferencePaths = @($resolved.PrimaryReferencePaths)
}
$buildFingerprintJson = $buildFingerprint | ConvertTo-Json -Depth 4

$needsBuild = -not (Test-Path -LiteralPath $exe)
if (-not $needsBuild) {
    $needsBuild = (Get-Item -LiteralPath $source).LastWriteTimeUtc -gt (Get-Item -LiteralPath $exe).LastWriteTimeUtc
}
if ((-not $needsBuild) -and (Test-Path -LiteralPath $buildMetadataPath)) {
    $existingFingerprintJson = (Get-Content -LiteralPath $buildMetadataPath -Raw).Trim()
    if ($existingFingerprintJson -ne $buildFingerprintJson.Trim()) {
        $needsBuild = $true
    }
}
elseif (-not $needsBuild) {
    $needsBuild = $true
}

if ($needsBuild) {
    $cscArgs = @(
        "/nologo"
        "/platform:x64"
        "/target:exe"
        "/out:$exe"
        "/reference:System.Core.dll"
    )

    foreach ($referencePath in $resolved.PrimaryReferencePaths) {
        $cscArgs += "/reference:$referencePath"
    }
    $cscArgs += $source

    & $csc @cscArgs

    if ($LASTEXITCODE -ne 0) {
        throw "TiaPlcTool build failed for $($resolved.VersionTag) with exit code $LASTEXITCODE"
    }

    $buildFingerprintJson | Set-Content -LiteralPath $buildMetadataPath -Encoding UTF8
}

if ($commandName -ne "help") {
    if (-not (Test-Path -LiteralPath $probeScript)) {
        throw "Probe script not found: $probeScript"
    }

    $probeArgs = @()
    if ($projectForProbe) {
        $probeArgs += @("-ProjectPath", $projectForProbe)
    }
    if ($resolved.VersionTag) {
        $probeArgs += @("-PreferredVersion", $resolved.VersionTag)
    }
    if ($resolved.TiaRoot) {
        $probeArgs += @("-TiaPortalLocation", $resolved.TiaRoot)
    }
    if ($resolved.PublicApiRoot) {
        $probeArgs += @("-TiaPortalPublicApiPath", $resolved.PublicApiRoot)
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

$env:TiaPortalLocation = $resolved.TiaRoot
$env:TiaPortalPublicApiPath = $resolved.PublicApiRoot
$env:CODEX_TIA_PREFERRED_VERSION = $resolved.VersionTag

& $exe @ToolArgs
exit $LASTEXITCODE
