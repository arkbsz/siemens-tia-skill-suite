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
  console [-ProjectPath <projectDir|ap16..ap21>] [-Wait] [-ForceBuild]
  console-exe [-ProjectPath <projectDir|ap16..ap21>] [-Wait] [-ForceBuild]
  console-web [-ProjectPath <projectDir|ap16..ap21>] [-Port <n>] [-Background] [-NoOpen]
  agent-chat -ProjectPath <projectDir|ap16..ap21> -PromptFile <text> [-AgentId <id>] [-Workflow <id>] [-RoutingMode auto|manual] [-Platform auto|codex|claude-code|trae-agent|qoder] [-Model <id>] [-SessionId <id>] [-AttachmentManifest <text>] [-Sandbox <mode>] [-Search]
  agent-plan -ProjectPath <projectDir|ap16..ap21> [-WorkflowConfigPath <json>] [-TaskText <text>] [-Workflow <id>] [-AgentId <id>] [-ReferenceImagePath <image>] [-OutputDirectory <dir>]
  agent-queue -ProjectPath <projectDir|ap16..ap21> [-WorkflowConfigPath <json>] [-PlanPath <json>] [-TaskText <text>] [-OutputDirectory <dir>]
  queue-stage -ProjectPath <projectDir|ap16..ap21> [-Action start-next|record-current|complete-current|fail-current|block-current|reset] [-QueuePath <json>] [-Note <text>] [-EvidencePath <path>]
  queue-run-current -ProjectPath <projectDir|ap16..ap21> [-WorkflowConfigPath <json>] [-QueuePath <json>] [-RoutingMode auto|manual] [-Platform auto|codex|claude-code|trae-agent|qoder] [-Model <id>] [-Sandbox read-only|workspace-write|danger-full-access] [-TimeoutSeconds <n>] [-Search] [-CompleteOnSuccess]
  review-package -ProjectPath <projectDir|ap16..ap21> [-WorkflowConfigPath <json>] [-OutputDirectory <dir>]
  workbench-dashboard -ProjectPath <projectDir|ap16..ap21> [-WorkflowConfigPath <json>] [-OutputDirectory <dir>]
  capability-map -ProjectPath <projectDir|ap16..ap21> [-WorkflowConfigPath <json>] [-TaskText <text>] [-OutputDirectory <dir>]
  project-model -ProjectPath <projectDir|ap16..ap21> [-WorkflowConfigPath <json>] [-TaskText <text>] [-OutputDirectory <dir>]
  knowledge-pack -ProjectPath <projectDir|ap16..ap21> [-WorkflowConfigPath <json>] [-TaskText <text>] [-OutputDirectory <dir>] [-RefreshOnline]
  plc-instruction-cookbook -ProjectPath <projectDir|ap16..ap21> [-WorkflowConfigPath <json>] [-TaskText <text>] [-OutputDirectory <dir>]
  simulation-package -ProjectPath <projectDir|ap16..ap21> [-WorkflowConfigPath <json>] [-TaskText <text>] [-OutputDirectory <dir>]
  simulation-replay -ProjectPath <projectDir|ap16..ap21> [-WorkflowConfigPath <json>] [-SimulationPackagePath <json>] [-ScenarioId <id>] [-OutputDirectory <dir>] [-Strict]
  agent-pipeline -ProjectPath <projectDir|ap16..ap21> [-WorkflowConfigPath <json>] [-TaskText <text>] [-ReferenceImagePath <image>] [-SourceXml <xml>] [-OutputDirectory <dir>] [-RefreshWinccCatalog] [-SkipAgentQueue]
  plc-instruction-plan -ProjectPath <projectDir|ap16..ap21> [-WorkflowConfigPath <json>] [-TaskText <text>] [-SourceXml <xml>] [-OutputDirectory <dir>]
  plc-change-package -ProjectPath <projectDir|ap16..ap21> [-WorkflowConfigPath <json>] [-TaskText <text>] [-Workflow <id>] [-SourceXml <xml>] [-OutputDirectory <dir>]
  probe-ai-platforms [-WorkflowConfigPath <json>]
  wincc-plugins -ProjectPath <projectDir|ap16..ap21> [-WorkflowConfigPath <json>] [-TaskText <text>] [-ReferenceImagePath <image>] [-RefreshCatalog]
  wincc-visual-package -ProjectPath <projectDir|ap16..ap21> [-WorkflowConfigPath <json>] [-TaskText <text>] [-ReferenceImagePath <image>] [-OutputDirectory <dir>]
  wincc-design-workflow -ProjectPath <projectDir|ap16..ap21> -DesignSpecPath <json> [-WorkflowConfigPath <json>] [-ReferenceImagePath <image>] [-ForCloneOnly]
  wincc-component-blueprints -ProjectPath <projectDir|ap16..ap21> [-WorkflowConfigPath <json>] [-TaskText <text>] [-ReferenceImagePath <image>] [-OutputDirectory <dir>]
  wincc-engineering-scaffold -ProjectPath <projectDir|ap16..ap21> [-WorkflowConfigPath <json>] [-TaskText <text>] [-ReferenceImagePath <image>] [-OutputDirectory <dir>]
  wincc-openness-implementation -ProjectPath <projectDir|ap16..ap21> [-WorkflowConfigPath <json>] [-EngineeringScaffoldPath <json>] [-OutputDirectory <dir>] [-ForCloneOnly]
  wincc-read-cycle -ProjectPath <projectDir|ap16..ap21> [-HmiName <name>] [-WorkflowConfigPath <json>] [-UseUi] [-Attach]
  wincc-apply-clone -ProjectPath <projectDir|ap16..ap21> [-HmiDeviceName <name>] [-ImplementationPath <dir>] -ApplyToClone
  doctor [-ProjectPath <projectDir|ap16..ap21>]
  create-project --name <projectName> [--directory <dir>] [--device-type <typeIdentifier>] [--device-item-type <typeIdentifier>] [--item-name <name>] [--device-name <name>]
  hold-project --project <projectDir|ap16..ap21> [--ui] [--lease-file <path>] [--poll-ms <ms>]
  probe [-ProjectPath <projectDir|ap16..ap21>]
  backup-project -ProjectPath <projectDir|ap16..ap21>
  clone-project -ProjectPath <projectDir|ap16..ap21> [-CloneRoot <dir>] [-CloneName <name>]
  read-cycle -ProjectPath <projectDir|ap16..ap21> [-PlcName <name>] [-RunName <name>] [-Languages LAD,FBD,SCL] [-WorkflowConfigPath <json>] [-UseUi] [-Attach] [-SkipExport]
  write-cycle -ProjectPath <projectDir|ap16..ap21> -InputXml <xml> [-PlcName <name>] [-ChangeName <name>] [-ReleaseName <name>] [-WorkflowConfigPath <json>] [-StepTimeoutSeconds <n>] [-SkipRelease]
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
  list-hmi --project <projectDir|ap16..ap21> [--hmi <name>]
  read-hmi --project <projectDir|ap16..ap21> [--hmi <name>] [--output <dir>] [--no-export]
  import-hmi --project <projectDir|ap16..ap21> --input <xml|dir> [--hmi <name>] [--kind auto|screen|tagtable|connection] [--apply] [--no-save]
  apply-hmi-manifest --project <projectDir|ap16..ap21> [--hmi <name>] [--tag-csv <csv>] [--alarm-csv <csv>] [--screen-csv <csv>] [--apply]
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
$aiPlatformAgentScript = Join-Path $PSScriptRoot "invoke-ai-platform-agent.ps1"
$winccPluginScript = Join-Path (Join-Path $skillsRoot "siemens-wincc-hmi-dev") "scripts\resolve-wincc-plugins.ps1"
$winccVisualPackageScript = Join-Path (Join-Path $skillsRoot "siemens-wincc-hmi-dev") "scripts\scaffold-wincc-visual-package.ps1"
$winccDesignWorkflowScript = Join-Path $PSScriptRoot "run-wincc-design-workflow.ps1"
$winccComponentBlueprintScript = Join-Path (Join-Path $skillsRoot "siemens-wincc-hmi-dev") "scripts\scaffold-wincc-component-blueprints.ps1"
$winccEngineeringScaffoldScript = Join-Path (Join-Path $skillsRoot "siemens-wincc-hmi-dev") "scripts\scaffold-wincc-engineering-package.ps1"
$winccOpennessImplementationScript = Join-Path (Join-Path $skillsRoot "siemens-wincc-hmi-dev") "scripts\scaffold-wincc-openness-implementation.ps1"
$winccReadCycleScript = Join-Path $PSScriptRoot "run-wincc-read-cycle.ps1"
$winccApplyCloneScript = Join-Path $PSScriptRoot "run-wincc-implementation.ps1"

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

$projectCommands = @("create-project", "hold-project", "list-devices", "list-plcs", "list-blocks", "list-hmi", "read-hmi", "import-hmi", "apply-hmi-manifest", "export-blocks", "import-blocks", "import-sources", "compile-plc")

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
    "console" {
        Invoke-PowerShellFile -Path (Join-Path $PSScriptRoot "start-plc-dev-console-exe.ps1") -Arguments $CommandArgs
        break
    }
    "console-exe" {
        Invoke-PowerShellFile -Path (Join-Path $PSScriptRoot "start-plc-dev-console-exe.ps1") -Arguments $CommandArgs
        break
    }
    "console-web" {
        Invoke-PowerShellFile -Path (Join-Path $PSScriptRoot "start-plc-dev-console.ps1") -Arguments $CommandArgs
        break
    }
    "agent-chat" {
        if (-not (Test-Path -LiteralPath $aiPlatformAgentScript)) {
            throw "Unified AI platform adapter was not found: $aiPlatformAgentScript"
        }
        Invoke-PowerShellFile -Path $aiPlatformAgentScript -Arguments $CommandArgs
        break
    }
    "agent-plan" {
        Invoke-PowerShellFile -Path (Join-Path $PSScriptRoot "generate-agent-task-plan.ps1") -Arguments $CommandArgs
        break
    }
    "agent-queue" {
        Invoke-PowerShellFile -Path (Join-Path $PSScriptRoot "generate-agent-execution-queue.ps1") -Arguments $CommandArgs
        break
    }
    "queue-stage" {
        Invoke-PowerShellFile -Path (Join-Path $PSScriptRoot "update-agent-execution-queue.ps1") -Arguments $CommandArgs
        break
    }
    "queue-run-current" {
        Invoke-PowerShellFile -Path (Join-Path $PSScriptRoot "run-agent-queue-stage.ps1") -Arguments $CommandArgs
        break
    }
    "review-package" {
        Invoke-PowerShellFile -Path (Join-Path $PSScriptRoot "generate-workbench-review-package.ps1") -Arguments $CommandArgs
        break
    }
    "workbench-dashboard" {
        Invoke-PowerShellFile -Path (Join-Path $PSScriptRoot "generate-workbench-dashboard.ps1") -Arguments $CommandArgs
        break
    }
    "capability-map" {
        Invoke-PowerShellFile -Path (Join-Path $PSScriptRoot "generate-workbench-capability-map.ps1") -Arguments $CommandArgs
        break
    }
    "project-model" {
        Invoke-PowerShellFile -Path (Join-Path $PSScriptRoot "generate-project-object-model.ps1") -Arguments $CommandArgs
        break
    }
    "knowledge-pack" {
        Invoke-PowerShellFile -Path (Join-Path $PSScriptRoot "generate-knowledge-pack.ps1") -Arguments $CommandArgs
        break
    }
    "plc-instruction-cookbook" {
        Invoke-PowerShellFile -Path (Join-Path $PSScriptRoot "generate-plc-instruction-cookbook.ps1") -Arguments $CommandArgs
        break
    }
    "simulation-package" {
        Invoke-PowerShellFile -Path (Join-Path $PSScriptRoot "generate-simulation-package.ps1") -Arguments $CommandArgs
        break
    }
    "simulation-replay" {
        Invoke-PowerShellFile -Path (Join-Path $PSScriptRoot "run-simulation-scenario-replay.ps1") -Arguments $CommandArgs
        break
    }
    "agent-pipeline" {
        Invoke-PowerShellFile -Path (Join-Path $PSScriptRoot "run-agent-development-pipeline.ps1") -Arguments $CommandArgs
        break
    }
    "plc-instruction-plan" {
        Invoke-PowerShellFile -Path (Join-Path $PSScriptRoot "generate-plc-instruction-plan.ps1") -Arguments $CommandArgs
        break
    }
    "plc-change-package" {
        Invoke-PowerShellFile -Path (Join-Path $PSScriptRoot "scaffold-plc-change-package.ps1") -Arguments $CommandArgs
        break
    }
    "probe-ai-platforms" {
        Invoke-PowerShellFile -Path (Join-Path $PSScriptRoot "probe-ai-platforms.ps1") -Arguments $CommandArgs
        break
    }
    "wincc-plugins" {
        if (-not (Test-Path -LiteralPath $winccPluginScript)) {
            throw "WinCC plugin resolver was not found: $winccPluginScript"
        }
        Invoke-PowerShellFile -Path $winccPluginScript -Arguments $CommandArgs
        break
    }
    "wincc-visual-package" {
        if (-not (Test-Path -LiteralPath $winccVisualPackageScript)) {
            throw "WinCC visual package scaffold was not found: $winccVisualPackageScript"
        }
        Invoke-PowerShellFile -Path $winccVisualPackageScript -Arguments $CommandArgs
        break
    }
    "wincc-design-workflow" {
        if (-not (Test-Path -LiteralPath $winccDesignWorkflowScript)) {
            throw "WinCC design workflow was not found: $winccDesignWorkflowScript"
        }
        Invoke-PowerShellFile -Path $winccDesignWorkflowScript -Arguments $CommandArgs
        break
    }
    "wincc-component-blueprints" {
        if (-not (Test-Path -LiteralPath $winccComponentBlueprintScript)) {
            throw "WinCC component blueprint scaffold was not found: $winccComponentBlueprintScript"
        }
        Invoke-PowerShellFile -Path $winccComponentBlueprintScript -Arguments $CommandArgs
        break
    }
    "wincc-engineering-scaffold" {
        if (-not (Test-Path -LiteralPath $winccEngineeringScaffoldScript)) {
            throw "WinCC engineering scaffold was not found: $winccEngineeringScaffoldScript"
        }
        Invoke-PowerShellFile -Path $winccEngineeringScaffoldScript -Arguments $CommandArgs
        break
    }
    "wincc-openness-implementation" {
        if (-not (Test-Path -LiteralPath $winccOpennessImplementationScript)) {
            throw "WinCC Openness implementation scaffold was not found: $winccOpennessImplementationScript"
        }
        Invoke-PowerShellFile -Path $winccOpennessImplementationScript -Arguments $CommandArgs
        break
    }
    "wincc-read-cycle" {
        if (-not (Test-Path -LiteralPath $winccReadCycleScript)) {
            throw "WinCC read-cycle script was not found: $winccReadCycleScript"
        }
        Invoke-PowerShellFile -Path $winccReadCycleScript -Arguments $CommandArgs
        break
    }
    "wincc-apply-clone" {
        if (-not (Test-Path -LiteralPath $winccApplyCloneScript)) {
            throw "WinCC clone implementation script was not found: $winccApplyCloneScript"
        }
        Invoke-PowerShellFile -Path $winccApplyCloneScript -Arguments $CommandArgs
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
    "read-cycle" {
        Invoke-PowerShellFile -Path (Join-Path $PSScriptRoot "run-plc-read-cycle.ps1") -Arguments $CommandArgs
        break
    }
    "write-cycle" {
        Invoke-PowerShellFile -Path (Join-Path $PSScriptRoot "run-plc-write-cycle.ps1") -Arguments $CommandArgs
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
