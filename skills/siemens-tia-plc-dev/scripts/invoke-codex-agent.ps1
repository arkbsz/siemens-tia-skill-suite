param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    [Parameter(Mandatory = $true)]
    [string]$PromptFile,

    [string]$AgentId = "auto",

    [string]$Model = "inherit",

    [string]$SessionId = "",

    [string]$AttachmentManifest = "",

    [ValidateSet("read-only", "workspace-write", "danger-full-access")]
    [string]$Sandbox = "workspace-write",

    [switch]$Search,

    [string]$ProfilesPath = "",

    [string]$Workflow = "project-read",

    [string]$WorkflowConfigPath = ""
)

$ErrorActionPreference = "Stop"
$adapter = Join-Path $PSScriptRoot "invoke-ai-platform-agent.ps1"
if (-not (Test-Path -LiteralPath $adapter -PathType Leaf)) {
    throw "Unified AI platform adapter was not found: $adapter"
}

$arguments = @(
    "-ProjectPath", $ProjectPath,
    "-PromptFile", $PromptFile,
    "-AgentId", $AgentId,
    "-Workflow", $Workflow,
    "-RoutingMode", "manual",
    "-Platform", "codex",
    "-Model", $Model,
    "-Sandbox", $Sandbox
)
if ($SessionId) { $arguments += @("-SessionId", $SessionId, "-SessionPlatform", "codex") }
if ($AttachmentManifest) { $arguments += @("-AttachmentManifest", $AttachmentManifest) }
if ($ProfilesPath) { $arguments += @("-ProfilesPath", $ProfilesPath) }
if ($WorkflowConfigPath) { $arguments += @("-WorkflowConfigPath", $WorkflowConfigPath) }
if ($Search) { $arguments += "-Search" }

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $adapter @arguments
exit $LASTEXITCODE
