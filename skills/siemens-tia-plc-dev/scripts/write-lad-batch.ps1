param(
    [Parameter(Mandatory = $true)]
    [string]$TargetXml,

    [Parameter(Mandatory = $true)]
    [string]$ManifestPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputXml
)

$ErrorActionPreference = "Stop"

function Wait-ForFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [int]$TimeoutSeconds = 10
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if (Test-Path -LiteralPath $Path) {
            return (Get-Item -LiteralPath $Path).FullName
        }
        Start-Sleep -Milliseconds 250
    }

    throw "Expected output file was not created in time: $Path"
}

$writeScript = Join-Path $PSScriptRoot "write-lad-network-from-json.ps1"
if (-not (Test-Path -LiteralPath $writeScript)) {
    throw "Missing dependency script: $writeScript"
}

$manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $manifest -or -not $manifest.steps -or $manifest.steps.Count -eq 0) {
    throw "Manifest must contain a non-empty steps array."
}

$resolvedTarget = (Get-Item -LiteralPath $TargetXml).FullName
$resolvedManifest = (Get-Item -LiteralPath $ManifestPath).FullName
$manifestDirectory = Split-Path -Parent $resolvedManifest
$resolvedOutputDir = Split-Path -Parent $OutputXml
if ($resolvedOutputDir) {
    New-Item -ItemType Directory -Path $resolvedOutputDir -Force | Out-Null
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-lad-batch-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

$currentXml = $resolvedTarget
$stepResults = @()

try {
    for ($i = 0; $i -lt $manifest.steps.Count; $i++) {
        $step = $manifest.steps[$i]
        $networkIndex = [int]$step.networkIndex
        $rawSpecPath = [string]$step.specPath
        $resolvedSpecPath = if ([System.IO.Path]::IsPathRooted($rawSpecPath)) {
            $rawSpecPath
        }
        else {
            Join-Path $manifestDirectory $rawSpecPath
        }
        $specPath = (Get-Item -LiteralPath $resolvedSpecPath).FullName
        $isLast = $i -eq ($manifest.steps.Count - 1)
        $stepOutput = if ($isLast) {
            $OutputXml
        }
        else {
            Join-Path $tempRoot ("step-{0:D2}.xml" -f ($i + 1))
        }

        $writeOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $writeScript `
            -TargetXml $currentXml `
            -SpecPath $specPath `
            -OutputXml $stepOutput `
            -NetworkIndex $networkIndex 2>&1

        if ($LASTEXITCODE -ne 0) {
            throw "write-lad-network-from-json failed at step $($i + 1)."
        }

        $currentXml = Wait-ForFile -Path $stepOutput
        $writeSummary = $null
        if ($writeOutput) {
            $writeText = ($writeOutput | Out-String).Trim()
            if (-not [string]::IsNullOrWhiteSpace($writeText)) {
                try {
                    $writeSummary = $writeText | ConvertFrom-Json
                }
                catch {
                    $writeSummary = $writeText
                }
            }
        }
        $stepResults += [pscustomobject]@{
            Step = $i + 1
            NetworkIndex = $networkIndex
            SpecPath = $specPath
            OutputXml = $currentXml
            WriteSummary = $writeSummary
        }
    }

    [pscustomobject]@{
        TargetXml = $resolvedTarget
        ManifestPath = $resolvedManifest
        OutputXml = (Wait-ForFile -Path $currentXml)
        Steps = $stepResults
    } | ConvertTo-Json -Depth 6
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
