param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    [string]$ConsolePath = "",

    [int]$TimeoutSeconds = 45
)

$ErrorActionPreference = "Stop"

$skillRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ConsolePath)) {
    $ConsolePath = Join-Path $skillRoot "app\bin\PLCDevConsole.exe"
}
$invokeScript = Join-Path $skillRoot "scripts\invoke-siemens-plc-dev.ps1"
$jobsRoot = Join-Path $ProjectPath "PLC_Code\console-jobs"

foreach ($requiredPath in @($ProjectPath, $ConsolePath, $invokeScript)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Required path was not found: $requiredPath"
    }
}

New-Item -ItemType Directory -Path $jobsRoot -Force | Out-Null
$before = @{}
foreach ($path in Get-ChildItem -LiteralPath $jobsRoot -Filter "*.json" -File -ErrorAction SilentlyContinue) {
    $before[$path.FullName] = $true
}

$process = $null
$launchTime = Get-Date
try {
    $process = Start-Process -FilePath $ConsolePath -ArgumentList @(
        "--project", (Resolve-Path -LiteralPath $ProjectPath).Path,
        "--invoke", (Resolve-Path -LiteralPath $invokeScript).Path,
        "--run-command", "doctor"
    ) -PassThru -WindowStyle Normal

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $job = $null
    while ((Get-Date) -lt $deadline) {
        $process.Refresh()
        if ($process.HasExited -and $null -eq $job) {
            throw "Workbench process exited before the command job was persisted. ExitCode=$($process.ExitCode)"
        }
        $candidates = @(
            Get-ChildItem -LiteralPath $jobsRoot -Filter "*.json" -File -ErrorAction SilentlyContinue |
                Where-Object { -not $before.ContainsKey($_.FullName) } |
                Sort-Object LastWriteTime -Descending
        )
        foreach ($candidate in $candidates) {
            try {
                $value = Get-Content -LiteralPath $candidate.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
                if ([string]$value.command -eq "doctor") {
                    $job = $value
                    break
                }
            }
            catch {
            }
        }
        if ($null -ne $job -and [string]$job.status -ne "RUNNING") {
            break
        }
        Start-Sleep -Milliseconds 300
    }

    if ($null -eq $job) {
        throw "The command palette did not create a persisted doctor job."
    }
    if ([string]$job.status -ne "SUCCEEDED" -or -not [bool]$job.hasExitCode -or [int]$job.exitCode -ne 0) {
        throw "The persisted doctor job did not succeed. Status=$($job.status), ExitCode=$($job.exitCode)"
    }

    $evidence = @(
        [string]$job.manifestPath,
        [string]$job.configSnapshotPath,
        [string]$job.stdoutPath,
        [string]$job.stderrPath
    )
    foreach ($path in $evidence) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Persisted job evidence is missing: $path"
        }
    }

    [pscustomobject]@{
        Status = "Passed"
        Command = "doctor"
        JobId = [string]$job.jobId
        JobStatus = [string]$job.status
        ExitCode = [int]$job.exitCode
        Manifest = [string]$job.manifestPath
        ConfigSnapshot = [string]$job.configSnapshotPath
        Stdout = [string]$job.stdoutPath
        Stderr = [string]$job.stderrPath
    } | ConvertTo-Json -Depth 5
}
finally {
    if ($null -ne $process) {
        try {
            if (-not $process.HasExited) {
                $treeKill = Start-Process -FilePath "taskkill.exe" -ArgumentList @(
                    "/PID", $process.Id.ToString(), "/T", "/F"
                ) -PassThru -WindowStyle Hidden
                [void]$treeKill.WaitForExit(5000)
                $treeKill.Dispose()
            }
        }
        catch {
        }
    }
    try {
        $children = @(
            Get-Process -Name "PLCDevConsole" -ErrorAction SilentlyContinue |
                Where-Object { $_.StartTime -ge $launchTime.AddSeconds(-1) }
        )
        foreach ($child in $children) {
            if (-not $child.HasExited) {
                Stop-Process -Id $child.Id -Force
            }
        }
    }
    catch {
    }
    if ($null -ne $process) {
        $process.Dispose()
    }
}
