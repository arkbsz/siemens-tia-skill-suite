param(
    [string]$ProjectPath = "",

    [string]$ListenHost = "127.0.0.1",

    [int]$Port = 8788,

    [switch]$Background,

    [switch]$NoOpen,

    [switch]$VisibleWindow
)

$ErrorActionPreference = "Stop"

$consoleScript = Join-Path $PSScriptRoot "plc_dev_console.py"
if (-not (Test-Path -LiteralPath $consoleScript)) {
    throw "Missing console script: $consoleScript"
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
    $consoleScript,
    "--host", $ListenHost,
    "--port", $Port.ToString()
)

if ($ProjectPath) {
    $argumentList += @("--project", $ProjectPath)
}

if (-not $NoOpen) {
    $argumentList += "--open"
}

$url = "http://{0}:{1}" -f $ListenHost, $Port

if ($Background) {
    $windowStyle = if ($VisibleWindow) { "Normal" } else { "Hidden" }
    $process = Start-Process -FilePath $pythonCommand -ArgumentList $argumentList -PassThru -WindowStyle $windowStyle
    [pscustomobject]@{
        Url = $url
        Host = $ListenHost
        Port = $Port
        ProcessId = $process.Id
        ProjectPath = $ProjectPath
        Script = $consoleScript
    } | ConvertTo-Json -Depth 4
    exit 0
}

& $pythonCommand @argumentList
exit $LASTEXITCODE
