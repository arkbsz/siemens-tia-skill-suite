param(
    [string]$ProjectPath = (Get-Location).Path,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$AllArgs
)

$ErrorActionPreference = "Stop"

if ($AllArgs.Count -eq 0 -and $ProjectPath -and -not (Test-Path -LiteralPath $ProjectPath)) {
    $AllArgs = @($ProjectPath)
    $ProjectPath = (Get-Location).Path
}

if (-not $AllArgs -or $AllArgs.Count -eq 0) {
    $AllArgs = @("help")
}

$command = $AllArgs[0].ToLowerInvariant()
$commandArgs = if ($AllArgs.Count -gt 1) { $AllArgs[1..($AllArgs.Count - 1)] } else { @() }

function Resolve-GenericSkillRoot {
    $localSkillsRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $sibling = Join-Path $localSkillsRoot "siemens-tia-plc-dev"
    if (Test-Path -LiteralPath $sibling) {
        return $sibling
    }

    return (Join-Path $env:USERPROFILE ".codex\skills\siemens-tia-plc-dev")
}

$genericRoot = Resolve-GenericSkillRoot
$genericInvoke = Join-Path $genericRoot "scripts\invoke-siemens-plc-dev.ps1"
$bridgeStart = Join-Path $genericRoot "scripts\start-tia-rest-bridge.ps1"
$prepareSession = Join-Path $genericRoot "scripts\prepare-write-session.ps1"

if (-not (Test-Path -LiteralPath $genericInvoke)) {
    throw "Missing generic Siemens skill wrapper: $genericInvoke"
}

function Invoke-Wrapper {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $genericInvoke @Arguments
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

function Test-HasNonAscii {
    param([string]$Value)

    foreach ($char in $Value.ToCharArray()) {
        if ([int][char]$char -gt 127) {
            return $true
        }
    }

    return $false
}

function Get-BridgeSessionInfo {
    $json = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $prepareSession -ProjectPath $ProjectPath
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }

    return ($json | ConvertFrom-Json)
}

function Invoke-RestBridge {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Endpoint,

        [Parameter(Mandatory = $true)]
        [hashtable]$Body
    )

    $jsonBody = $Body | ConvertTo-Json -Depth 10
    return Invoke-RestMethod -Method Post -Uri $Endpoint -ContentType "application/json" -Body $jsonBody
}

function Get-OptionValue {
    param(
        [string[]]$ArgumentList,
        [string[]]$Names
    )

    for ($i = 0; $i -lt $ArgumentList.Count; $i++) {
        foreach ($name in $Names) {
            if ($ArgumentList[$i] -eq $name -and ($i + 1) -lt $ArgumentList.Count) {
                return $ArgumentList[$i + 1]
            }
        }
    }

    return $null
}

function Invoke-RestReadCommand {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("list-plcs", "list-blocks", "export-blocks")]
        [string]$CommandName
    )

    $session = Get-BridgeSessionInfo
    $projectForBridge = $session.BridgeProjectPath
    $baseUrl = $session.BaseUrl.TrimEnd("/")

    if ($CommandName -eq "list-plcs") {
        return Invoke-RestBridge -Endpoint ($baseUrl + "/api/v1/tia/list-plcs") -Body @{
            projectPath = $projectForBridge
            useSession = $true
        }
    }

    if ($CommandName -eq "list-blocks") {
        $body = @{
            projectPath = $projectForBridge
            useSession = $true
        }

        $plc = Get-OptionValue -ArgumentList $commandArgs -Names @("--plc")
        if ($plc) {
            $body["plc"] = $plc
        }

        return Invoke-RestBridge -Endpoint ($baseUrl + "/api/v1/tia/list-blocks") -Body $body
    }

    $body = @{
        projectPath = $projectForBridge
        useSession = $true
    }

    $plc = Get-OptionValue -ArgumentList $commandArgs -Names @("--plc")
    $block = Get-OptionValue -ArgumentList $commandArgs -Names @("--block")
    $output = Get-OptionValue -ArgumentList $commandArgs -Names @("--output")
    $language = Get-OptionValue -ArgumentList $commandArgs -Names @("--language")
    if ($plc) {
        $body["plc"] = $plc
    }
    if ($block) {
        $body["block"] = $block
    }
    if ($language) {
        $body["language"] = $language
    }
    if ($output) {
        if ($session.UsedAsciiAlias -and $output.StartsWith($ProjectPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            $output = $projectForBridge + $output.Substring($ProjectPath.Length)
        }
        $body["outputPath"] = $output
    }

    return Invoke-RestBridge -Endpoint ($baseUrl + "/api/v1/tia/export-blocks") -Body $body
}

function Write-JsonResult {
    param([Parameter(Mandatory = $true)] $Value)

    $Value | ConvertTo-Json -Depth 10
}

function Invoke-BridgeStart {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $bridgeStart -Background
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

function Show-Help {
@"
Codex TIA Client
ProjectPath: $ProjectPath

Commands:
  help
  route-info
  probe
  backup
  bootstrap
  refresh
  init-workspace
  session
  bridge-start
  list-plcs [--plc <name>]
  list-blocks [--plc <name>] [--block <name>]
  export-lad [--plc <name>] [--block <name>] [--output <dir>]
  export-scl [--plc <name>] [--block <name>] [--output <dir>]
  import-blocks --input <xml|dir> [--plc <name>] [--group <path>] [--apply] [--no-save]
  compile [--plc <name>] [--save]
  summarize-lad -Path <xml> -OutputPath <md>
  validate-lad -Path <xml>
  scaffold-lad-json -OutputPath <json> [-Title <text>] [-Comment <text>]
  write-lad-json -TargetXml <xml> -SpecPath <json> -OutputXml <xml> -NetworkIndex <n>
  write-lad-batch -TargetXml <xml> -ManifestPath <json> -OutputXml <xml>
  verify-lad -InputXml <xml> -PlcName <name> [-ChangeName <name>] [-CloneName <name>]
"@
}

switch ($command) {
    "help" {
        Show-Help
        break
    }
    "route-info" {
        Invoke-Wrapper -Arguments @("route-info")
        break
    }
    "probe" {
        Invoke-Wrapper -Arguments (@("probe", "-ProjectPath", $ProjectPath) + $commandArgs)
        break
    }
    "backup" {
        Invoke-Wrapper -Arguments (@("backup-project", "-ProjectPath", $ProjectPath) + $commandArgs)
        break
    }
    "bootstrap" {
        Invoke-Wrapper -Arguments (@("bootstrap", "-ProjectPath", $ProjectPath) + $commandArgs)
        break
    }
    "refresh" {
        Invoke-Wrapper -Arguments (@("refresh", "-ProjectPath", $ProjectPath) + $commandArgs)
        break
    }
    "init-workspace" {
        Invoke-Wrapper -Arguments (@("init-workspace", "-ProjectPath", $ProjectPath) + $commandArgs)
        break
    }
    "session" {
        Invoke-Wrapper -Arguments (@("prepare-write-session", "-ProjectPath", $ProjectPath) + $commandArgs)
        break
    }
    "bridge-start" {
        Invoke-BridgeStart
        break
    }
    "list-plcs" {
        if (Test-HasNonAscii -Value $ProjectPath) {
            Write-JsonResult (Invoke-RestReadCommand -CommandName "list-plcs")
        }
        else {
            Invoke-Wrapper -Arguments (@("list-plcs", "--project", $ProjectPath) + $commandArgs)
        }
        break
    }
    "list-blocks" {
        if (Test-HasNonAscii -Value $ProjectPath) {
            Write-JsonResult (Invoke-RestReadCommand -CommandName "list-blocks")
        }
        else {
            Invoke-Wrapper -Arguments (@("list-blocks", "--project", $ProjectPath) + $commandArgs)
        }
        break
    }
    "export-lad" {
        $defaultOutput = Join-Path $ProjectPath "PLC_Code\exports\lad"
        if (Test-HasNonAscii -Value $ProjectPath) {
            if (-not (Get-OptionValue -ArgumentList $commandArgs -Names @("--output"))) {
                $commandArgs = $commandArgs + @("--output", $defaultOutput)
            }
            $commandArgs = @("--language", "LAD") + $commandArgs
            Write-JsonResult (Invoke-RestReadCommand -CommandName "export-blocks")
        }
        else {
            Invoke-Wrapper -Arguments (@("export-blocks", "--project", $ProjectPath, "--language", "LAD", "--output", $defaultOutput) + $commandArgs)
        }
        break
    }
    "export-scl" {
        $defaultOutput = Join-Path $ProjectPath "PLC_Code\exports\scl"
        if (Test-HasNonAscii -Value $ProjectPath) {
            if (-not (Get-OptionValue -ArgumentList $commandArgs -Names @("--output"))) {
                $commandArgs = $commandArgs + @("--output", $defaultOutput)
            }
            $commandArgs = @("--language", "SCL") + $commandArgs
            Write-JsonResult (Invoke-RestReadCommand -CommandName "export-blocks")
        }
        else {
            Invoke-Wrapper -Arguments (@("export-blocks", "--project", $ProjectPath, "--language", "SCL", "--output", $defaultOutput) + $commandArgs)
        }
        break
    }
    "import-blocks" {
        Invoke-Wrapper -Arguments (@("import-blocks", "--project", $ProjectPath) + $commandArgs)
        break
    }
    "compile" {
        Invoke-Wrapper -Arguments (@("compile-plc", "--project", $ProjectPath) + $commandArgs)
        break
    }
    "summarize-lad" {
        Invoke-Wrapper -Arguments (@("summarize-lad") + $commandArgs)
        break
    }
    "validate-lad" {
        Invoke-Wrapper -Arguments (@("validate-lad") + $commandArgs)
        break
    }
    "scaffold-lad-json" {
        Invoke-Wrapper -Arguments (@("scaffold-lad-network-json") + $commandArgs)
        break
    }
    "write-lad-json" {
        Invoke-Wrapper -Arguments (@("write-lad-network") + $commandArgs)
        break
    }
    "write-lad-batch" {
        Invoke-Wrapper -Arguments (@("write-lad-batch") + $commandArgs)
        break
    }
    "verify-lad" {
        Invoke-Wrapper -Arguments (@("verify-lad-change", "-ProjectPath", $ProjectPath) + $commandArgs)
        break
    }
    default {
        throw "Unknown command '$command'. Run help to see supported commands."
    }
}
