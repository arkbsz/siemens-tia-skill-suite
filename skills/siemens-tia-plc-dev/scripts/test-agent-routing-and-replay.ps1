param(
    [string]$SkillRoot = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($SkillRoot)) {
    $SkillRoot = Split-Path -Parent $PSScriptRoot
}
$SkillRoot = (Resolve-Path -LiteralPath $SkillRoot).Path
$invokeScript = Join-Path $SkillRoot "scripts\invoke-ai-platform-agent.ps1"
$profilesPath = Join-Path $SkillRoot "agents\siemens-agent-profiles.json"
$platformsPath = Join-Path $SkillRoot "agents\ai-platforms.json"
$routesPath = Join-Path $SkillRoot "agents\siemens-workflow-routes.json"
$consoleSource = Join-Path $SkillRoot "app\PLCDevConsoleWin.cs"

foreach ($path in @($invokeScript, $profilesPath, $platformsPath, $routesPath, $consoleSource)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required test input was not found: $path"
    }
}

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("SiemensTiaAgentRouting-" + [guid]::NewGuid().ToString("N"))
$projectRoot = Join-Path $tempRoot "project"
$fakeBin = Join-Path $tempRoot "fake-bin"
$fakeCommand = Join-Path $fakeBin "fake-codex.cmd"
$promptPath = Join-Path $projectRoot "prompt.txt"
$configPath = Join-Path $projectRoot "ai-workflow.json"
$capturePath = Join-Path $fakeBin "last-args.txt"

New-Item -ItemType Directory -Path $projectRoot, $fakeBin -Force | Out-Null

try {
    @'
@echo off
set "CAPTURE=%~dp0last-args.txt"
> "%CAPTURE%" echo %*
echo {"type":"thread.started","thread_id":"fake-session"}
echo {"type":"item.completed","item":{"type":"agent_message","text":"fake response"}}
exit /b 0
'@ | Set-Content -LiteralPath $fakeCommand -Encoding ASCII

    Set-Content -LiteralPath $promptPath -Value "offline routing test" -Encoding UTF8
    [ordered]@{
        schemaVersion = 2
        projectRoot = $projectRoot
        platform = [ordered]@{
            routingMode = "manual"
            selected = "codex"
            codexCommand = $fakeCommand
        }
        routing = [ordered]@{
            workflow = "读取项目并总结"
        }
        agent = [ordered]@{
            profile = "auto"
        }
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $configPath -Encoding UTF8

    function Invoke-FakeAgent {
        param(
            [string]$SessionId = "",
            [string]$SessionPlatform = ""
        )

        $arguments = @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", $invokeScript,
            "-ProjectPath", $projectRoot,
            "-PromptFile", $promptPath,
            "-AgentId", "auto",
            "-Workflow", "project-read",
            "-RoutingMode", "manual",
            "-Platform", "codex",
            "-Model", "inherit",
            "-Sandbox", "read-only",
            "-WorkflowConfigPath", $configPath
        )
        if ($SessionId) {
            $arguments += @("-SessionId", $SessionId)
            if ($SessionPlatform) {
                $arguments += @("-SessionPlatform", $SessionPlatform)
            }
        }

        $output = @(& powershell.exe @arguments 2>&1)
        $exitCode = $LASTEXITCODE
        if ($exitCode -ne 0) {
            throw "Fake Agent invocation failed with exit code $exitCode.`n$($output -join [Environment]::NewLine)"
        }
        if (-not (Test-Path -LiteralPath $capturePath -PathType Leaf)) {
            throw "Fake Agent did not capture its command arguments."
        }

        [pscustomobject]@{
            Output = $output
            Arguments = Get-Content -LiteralPath $capturePath -Raw -Encoding Default
        }
    }

    $newRun = Invoke-FakeAgent
    $continueRun = Invoke-FakeAgent -SessionId "fake-session" -SessionPlatform "codex"
    $retryRun = Invoke-FakeAgent

    $resumePattern = "(?i)(^|\s)resume(\s|$)"
    if ($newRun.Arguments -match $resumePattern) {
        throw "New Agent invocation unexpectedly contained resume."
    }
    if ($continueRun.Arguments -notmatch $resumePattern -or
        $continueRun.Arguments -notmatch "(?i)fake-session") {
        throw "Continue Agent invocation did not contain the compatible session."
    }
    if ($retryRun.Arguments -match $resumePattern -or
        $retryRun.Arguments -match "(?i)fake-session") {
        throw "Retry Agent invocation unexpectedly retained the old session."
    }

    $sourceText = Get-Content -LiteralPath $consoleSource -Raw -Encoding UTF8
    foreach ($marker in @(
        'ReplaceAgentSessionArguments(args, "", "")',
        'CopyReplayPrompt',
        'CopyReplayAttachmentManifest',
        'job.StopRequested',
        'job.TimedOut'
    )) {
        if ($sourceText.IndexOf($marker, [StringComparison]::Ordinal) -lt 0) {
            throw "Replay hardening marker was not found in the console source: $marker"
        }
    }

    [pscustomobject]@{
        Status = "Passed"
        NewHasResume = [bool]($newRun.Arguments -match $resumePattern)
        ContinueHasResume = [bool]($continueRun.Arguments -match $resumePattern)
        RetryHasResume = [bool]($retryRun.Arguments -match $resumePattern)
        ContinueSession = "fake-session"
        RetrySessionCleared = [bool]($retryRun.Arguments -notmatch "(?i)fake-session")
        SourceContract = "Passed"
    } | ConvertTo-Json -Depth 5
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        try {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
        catch {
        }
    }
}
