param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$AllArgs
)

$ErrorActionPreference = "Stop"

$skillsRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $PSScriptRoot "resolve-bridge-skill.ps1")

$Command = if ($AllArgs.Count -gt 0) { $AllArgs[0] } else { "help" }
$CommandArgs = if ($AllArgs.Count -gt 1) { $AllArgs[1..($AllArgs.Count - 1)] } else { @() }

function Show-Help {
    @"
Siemens TIA PLC Dev
Commands:
  route-info
  doctor [-ProjectPath <projectDir|ap16..ap21>]
  create-project --name <projectName> [--directory <dir>] [--device-type <typeIdentifier>] [--device-item-type <typeIdentifier>] [--item-name <name>] [--device-name <name>]
  hold-project --project <projectDir|ap16..ap21> [--ui] [--lease-file <path>] [--poll-ms <ms>]
  probe [-ProjectPath <projectDir|ap16..ap21>]
  backup-project -ProjectPath <projectDir|ap16..ap21>
  clone-project -ProjectPath <projectDir|ap16..ap21> [-CloneRoot <dir>] [-CloneName <name>]
  bootstrap -ProjectPath <projectDir|ap16..ap21>
  refresh -ProjectPath <projectDir|ap16..ap21>
  init-workspace -ProjectPath <projectDir|ap16..ap21>
  prepare-write-session -ProjectPath <projectDir|ap16..ap21> [-BaseUrl <url>] [-StartupTimeoutSeconds <n>] [-Ui] [-SkipBridgeStart]
  scaffold-lad-change -ProjectPath <projectDir|ap16..ap21> -SourceXml <path> -ChangeName <name> [-NetworkIndex <n>] [-CreateTemplate]
  verify-lad-change -ProjectPath <projectDir|ap16..ap21> -InputXml <path> -PlcName <name> [-ChangeName <name>] [-CloneName <name>]
  prepare-release -ProjectPath <projectDir|ap16..ap21> -InputXml <path> -ReleaseName <name> [-ReadableSummaryPath <path>] [-VerificationReportPath <path>]
  apply-release -ProjectPath <projectDir|ap16..ap21> -InputXml <path> -PlcName <name> [-BlockName <name>] [-ReleaseLabel <name>] [-SkipBackup] [-DryRunOnly]

TIA project commands:
  hold-project --project <projectDir|ap16..ap21> [--ui] [--lease-file <path>] [--poll-ms <ms>]
  list-devices --project <projectDir|ap16..ap21>
  list-plcs --project <projectDir|ap16..ap21>
  list-blocks --project <projectDir|ap16..ap21> [--plc <name>]
  export-blocks --project <projectDir|ap16..ap21> [--plc <name>] [--block <name>] [--language LAD|FBD|SCL] [--output <dir>]
  import-blocks --project <projectDir|ap16..ap21> --input <xml|dir> [--plc <name>] [--group <path>] [--apply] [--no-save]
  import-sources --project <projectDir|ap16..ap21> [--plc <name>] --source-dir <dir> [--compile] [--save]
  compile-plc --project <projectDir|ap16..ap21> [--plc <name>] [--save]

LAD helper commands:
  inspect-lad -Path <xml>
  validate-lad -Path <xml>
  summarize-lad -Path <xml> -OutputPath <md>
  scaffold-lad-network-json -OutputPath <json> [-Title <text>] [-Comment <text>]
  write-lad-network -TargetXml <xml> -SpecPath <json> -OutputXml <xml> -NetworkIndex <n>
  write-lad-batch -TargetXml <xml> -ManifestPath <json> -OutputXml <xml>
  patch-lad-network -TargetXml <xml> -DonorXml <xml> -OutputXml <xml> -TargetNetworkIndex <n> [-DonorNetworkIndex <n>] [-CopyTitle] [-CopyComment]
  apply-lad-template -SourceXml <xml> -OutputXml <xml> -NetworkIndex <n> -Replace <old=new;...> [-Title <text>]
  export-lad-template -SourceXml <xml> -NetworkIndex <n> -OutputPath <template.json> -TemplateName <name>
  build-lad-catalog -Path <dir> -OutputPath <catalog.md>
  build-lad-index -Path <dir> -OutputPath <index.md>

Notes:
  - This generic wrapper routes to the best local tia-portal-vXX sibling skill on the machine.
  - This release is prepared to route TIA Portal V16 through V21 projects.
"@
}

function Invoke-PowerShellFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [string[]]$Arguments = @()
    )

    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Path @Arguments
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

$bridge = Resolve-TiaBridgeSkill -SkillsRoot $skillsRoot

$opennessScript = Resolve-TiaBridgeScript -SkillPath $bridge.SkillPath -Candidates @(
    "scripts\invoke-tia-openness.ps1"
)
$probeScript = Resolve-TiaBridgeScript -SkillPath $bridge.SkillPath -Candidates @(
    "scripts\probe-tia-portal.ps1",
    ("scripts\probe-tia-{0}.ps1" -f $bridge.Version.ToLowerInvariant()),
    "scripts\probe-tia-v17.ps1"
)
$backupScript = Resolve-TiaBridgeScript -SkillPath $bridge.SkillPath -Candidates @(
    "scripts\backup-tia-project.ps1"
)
$initScript = Resolve-TiaBridgeScript -SkillPath $bridge.SkillPath -Candidates @(
    "scripts\init-plc-code-workspace.ps1"
)
$inspectLadScript = Resolve-TiaBridgeScript -SkillPath $bridge.SkillPath -Candidates @(
    "scripts\inspect-lad-xml.ps1"
)
$validateLadScript = Resolve-TiaBridgeScript -SkillPath $bridge.SkillPath -Candidates @(
    "scripts\validate-lad-xml.ps1"
)
$summarizeLadScript = Resolve-TiaBridgeScript -SkillPath $bridge.SkillPath -Candidates @(
    "scripts\summarize-lad-xml.ps1"
)
$applyTemplateScript = Resolve-TiaBridgeScript -SkillPath $bridge.SkillPath -Candidates @(
    "scripts\apply-lad-template-replacements.ps1"
)
$exportTemplateScript = Resolve-TiaBridgeScript -SkillPath $bridge.SkillPath -Candidates @(
    "scripts\export-lad-network-template.ps1"
)
$buildCatalogScript = Resolve-TiaBridgeScript -SkillPath $bridge.SkillPath -Candidates @(
    "scripts\build-lad-template-catalog.ps1"
)
$buildIndexScript = Resolve-TiaBridgeScript -SkillPath $bridge.SkillPath -Candidates @(
    "scripts\build-lad-template-index.ps1"
)

$projectCommands = @("create-project", "hold-project", "list-devices", "list-plcs", "list-blocks", "export-blocks", "import-blocks", "import-sources", "compile-plc")

switch ($Command.ToLowerInvariant()) {
    "help" {
        Show-Help
        break
    }
    "route-info" {
        $available = @(
            Get-ChildItem -LiteralPath $skillsRoot -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like "tia-portal-v*" } |
                Sort-Object { [int](Get-TiaBridgeVersionNumber $_.Name) } -Descending |
                Select-Object -ExpandProperty FullName
        )

        [pscustomobject]@{
            SelectedBridge = $bridge
            AvailableBridgeSkills = $available
            GenericSkill = Split-Path -Parent $PSScriptRoot
        } | ConvertTo-Json -Depth 5
        break
    }
    "probe" {
        Invoke-PowerShellFile -Path $probeScript -Arguments $CommandArgs
        break
    }
    "doctor" {
        Invoke-PowerShellFile -Path $probeScript -Arguments $CommandArgs
        break
    }
    "backup-project" {
        Invoke-PowerShellFile -Path $backupScript -Arguments $CommandArgs
        break
    }
    "clone-project" {
        Invoke-PowerShellFile -Path (Join-Path $PSScriptRoot "clone-project-for-edit.ps1") -Arguments $CommandArgs
        break
    }
    "bootstrap" {
        Invoke-PowerShellFile -Path (Join-Path $PSScriptRoot "bootstrap-siemens-plc-dev.ps1") -Arguments $CommandArgs
        break
    }
    "refresh" {
        Invoke-PowerShellFile -Path (Join-Path $PSScriptRoot "refresh-plc-libraries.ps1") -Arguments $CommandArgs
        break
    }
    "prepare-write-session" {
        Invoke-PowerShellFile -Path (Join-Path $PSScriptRoot "prepare-write-session.ps1") -Arguments $CommandArgs
        break
    }
    "init-workspace" {
        Invoke-PowerShellFile -Path $initScript -Arguments $CommandArgs
        break
    }
    "scaffold-lad-change" {
        Invoke-PowerShellFile -Path (Join-Path $PSScriptRoot "scaffold-lad-change.ps1") -Arguments $CommandArgs
        break
    }
    "verify-lad-change" {
        Invoke-PowerShellFile -Path (Join-Path $PSScriptRoot "verify-lad-change-on-clone.ps1") -Arguments $CommandArgs
        break
    }
    "prepare-release" {
        Invoke-PowerShellFile -Path (Join-Path $PSScriptRoot "prepare-plc-release.ps1") -Arguments $CommandArgs
        break
    }
    "apply-release" {
        Invoke-PowerShellFile -Path (Join-Path $PSScriptRoot "apply-release-to-project.ps1") -Arguments $CommandArgs
        break
    }
    "inspect-lad" {
        Invoke-PowerShellFile -Path $inspectLadScript -Arguments $CommandArgs
        break
    }
    "validate-lad" {
        Invoke-PowerShellFile -Path $validateLadScript -Arguments $CommandArgs
        break
    }
    "summarize-lad" {
        Invoke-PowerShellFile -Path $summarizeLadScript -Arguments $CommandArgs
        break
    }
    "scaffold-lad-network-json" {
        Invoke-PowerShellFile -Path (Join-Path $PSScriptRoot "scaffold-lad-network-json.ps1") -Arguments $CommandArgs
        break
    }
    "write-lad-network" {
        Invoke-PowerShellFile -Path (Join-Path $PSScriptRoot "write-lad-network-from-json.ps1") -Arguments $CommandArgs
        break
    }
    "write-lad-batch" {
        Invoke-PowerShellFile -Path (Join-Path $PSScriptRoot "write-lad-batch.ps1") -Arguments $CommandArgs
        break
    }
    "patch-lad-network" {
        Invoke-PowerShellFile -Path (Join-Path $PSScriptRoot "patch-lad-network.ps1") -Arguments $CommandArgs
        break
    }
    "apply-lad-template" {
        Invoke-PowerShellFile -Path $applyTemplateScript -Arguments $CommandArgs
        break
    }
    "export-lad-template" {
        Invoke-PowerShellFile -Path $exportTemplateScript -Arguments $CommandArgs
        break
    }
    "build-lad-catalog" {
        Invoke-PowerShellFile -Path $buildCatalogScript -Arguments $CommandArgs
        break
    }
    "build-lad-index" {
        Invoke-PowerShellFile -Path $buildIndexScript -Arguments $CommandArgs
        break
    }
    default {
        if ($projectCommands -contains $Command.ToLowerInvariant()) {
            Invoke-PowerShellFile -Path $opennessScript -Arguments (@($Command) + $CommandArgs)
            break
        }

        throw "Unknown command '$Command'. Run 'help' to see the supported commands."
    }
}
