param(
    [string]$OutputPath = "",

    [switch]$Force
)

$ErrorActionPreference = "Stop"

$skillRoot = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $skillRoot "app\PLCDevConsoleWin.cs"
$binRoot = Join-Path $skillRoot "app\bin"

if (-not (Test-Path -LiteralPath $sourcePath)) {
    throw "Missing WinForms console source: $sourcePath"
}

if (-not $OutputPath) {
    $OutputPath = Join-Path $binRoot "PLCDevConsole.exe"
}

New-Item -ItemType Directory -Path (Split-Path -Parent $OutputPath) -Force | Out-Null

$cscCandidates = @(
    "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe",
    "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\csc.exe"
)

$cscPath = $null
foreach ($candidate in $cscCandidates) {
    if (Test-Path -LiteralPath $candidate) {
        $cscPath = $candidate
        break
    }
}

if (-not $cscPath) {
    $resolved = Get-Command csc.exe -ErrorAction SilentlyContinue
    if ($resolved) {
        $cscPath = $resolved.Source
    }
}

if (-not $cscPath) {
    throw "csc.exe was not found. Install .NET Framework Developer Pack or Visual Studio Build Tools."
}

if ((Test-Path -LiteralPath $OutputPath) -and -not $Force) {
    $sourceTime = (Get-Item -LiteralPath $sourcePath).LastWriteTimeUtc
    $outputTime = (Get-Item -LiteralPath $OutputPath).LastWriteTimeUtc
    if ($outputTime -ge $sourceTime) {
        [pscustomobject]@{
            Status = "UpToDate"
            ExePath = (Get-Item -LiteralPath $OutputPath).FullName
            Compiler = $cscPath
        } | ConvertTo-Json -Depth 4
        exit 0
    }
}

$references = @(
    "/reference:System.dll",
    "/reference:System.Core.dll",
    "/reference:System.Drawing.dll",
    "/reference:System.Xml.dll",
    "/reference:System.Windows.Forms.dll",
    "/reference:System.Web.Extensions.dll"
)

$arguments = @(
    "/nologo",
    "/target:winexe",
    "/platform:anycpu",
    "/codepage:65001",
    "/out:$OutputPath"
) + $references + @($sourcePath)

$output = & $cscPath @arguments 2>&1
$exitCode = $LASTEXITCODE
if ($exitCode -ne 0) {
    throw "PLCDevConsole.exe build failed with exit code $exitCode.`n$($output | Out-String)"
}

[pscustomobject]@{
    Status = "Built"
    ExePath = (Get-Item -LiteralPath $OutputPath).FullName
    Compiler = $cscPath
    Output = ($output | Out-String).Trim()
} | ConvertTo-Json -Depth 4
