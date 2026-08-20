param(
    [string]$ListenHost = "127.0.0.1",
    [int]$Port = 8765,
    [switch]$Background,
    [switch]$VisibleWindow
)

$ErrorActionPreference = "Stop"

$serverScript = Join-Path $PSScriptRoot "tia_rest_bridge.py"
if (-not (Test-Path -LiteralPath $serverScript)) {
    throw "Missing server script: $serverScript"
}

$pythonCommand = $null
foreach ($candidate in @("py", "python", "python3")) {
    $resolved = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($resolved) {
        $pythonCommand = $resolved.Source
        break
    }
}

if (-not $pythonCommand) {
    throw "Python was not found in PATH. Install Python or make 'py' available."
}

$argumentList = @()
if ((Split-Path -Leaf $pythonCommand) -ieq "py.exe" -or (Split-Path -Leaf $pythonCommand) -ieq "py") {
    $argumentList += "-3"
}
    $argumentList += @(
        $serverScript,
    "--host", $ListenHost,
    "--port", $Port.ToString()
)

if ($Background) {
    $windowStyle = if ($VisibleWindow) { "Normal" } else { "Hidden" }
    $process = Start-Process -FilePath $pythonCommand -ArgumentList $argumentList -PassThru -WindowStyle $windowStyle
    [pscustomobject]@{
        Host = $ListenHost
        Port = $Port
        ProcessId = $process.Id
        Url = "http://{0}:{1}" -f $ListenHost, $Port
        Script = $serverScript
    } | ConvertTo-Json -Depth 4
    exit 0
}

& $pythonCommand @argumentList
exit $LASTEXITCODE
