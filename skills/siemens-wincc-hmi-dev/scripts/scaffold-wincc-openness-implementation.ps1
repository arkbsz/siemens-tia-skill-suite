param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    [string]$WorkflowConfigPath = "",
    [string]$EngineeringScaffoldPath = "",
    [string]$OutputDirectory = "",
    [switch]$ForCloneOnly
)

$ErrorActionPreference = "Stop"
$nativeUtf8 = New-Object System.Text.UTF8Encoding($false)
$OutputEncoding = $nativeUtf8
[Console]::OutputEncoding = $nativeUtf8

function Resolve-ProjectDirectory {
    param([string]$Path)
    $item = Get-Item -LiteralPath $Path
    if ($item.PSIsContainer) { return $item.FullName }
    return $item.Directory.FullName
}

function Read-CsvRows {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) { return @() }
    return @(Import-Csv -LiteralPath $Path -Encoding UTF8)
}

function Add-ManifestItem {
    param($Items, [string]$Name, [string]$Path, [string]$Purpose, [string]$Status)
    [void]$Items.Add([pscustomobject]@{
        name = $Name
        path = $Path
        purpose = $Purpose
        status = $Status
    })
}

$root = Resolve-ProjectDirectory -Path $ProjectPath
$workspaceRoot = Join-Path $root "PLC_Code"
if ([string]::IsNullOrWhiteSpace($WorkflowConfigPath)) { $WorkflowConfigPath = Join-Path $workspaceRoot "config\ai-workflow.json" }
if ([string]::IsNullOrWhiteSpace($EngineeringScaffoldPath)) { $EngineeringScaffoldPath = Join-Path $workspaceRoot "wincc\engineering-scaffold\latest\wincc-engineering-scaffold.json" }
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $workspaceRoot ("wincc\openness-implementation\" + (Get-Date -Format "yyyyMMdd-HHmmss"))
}
$latestDir = Join-Path $workspaceRoot "wincc\openness-implementation\latest"
New-Item -ItemType Directory -Path $OutputDirectory, $latestDir -Force | Out-Null

if (-not (Test-Path -LiteralPath $EngineeringScaffoldPath -PathType Leaf)) {
    throw "WinCC engineering scaffold was not found. Run wincc-engineering-scaffold first: $EngineeringScaffoldPath"
}

$scaffold = Get-Content -LiteralPath $EngineeringScaffoldPath -Raw -Encoding UTF8 | ConvertFrom-Json
$scaffoldDir = Split-Path -Parent $EngineeringScaffoldPath
$tagCsv = Join-Path $scaffoldDir "hmi-tag-import-map.csv"
$alarmCsv = Join-Path $scaffoldDir "alarm-import-map.csv"
$tags = Read-CsvRows -Path $tagCsv
$alarms = Read-CsvRows -Path $alarmCsv

$screenRows = @(
    [pscustomobject]@{ screenName = "总览_Overview"; zone = "Header"; component = "Screen shell"; source = "screen-map.md"; implementation = "Openness screen scaffold or SiVArc template" },
    [pscustomobject]@{ screenName = "手动_Manual"; zone = "StationCards"; component = "FP_工位_Station"; source = "component-blueprints.md"; implementation = "Faceplate instances bound to HMI tags" },
    [pscustomobject]@{ screenName = "报警_Alarm"; zone = "AlarmStrip"; component = "Alarm view"; source = "alarm-import-map.csv"; implementation = "Alarm classes and trigger tags" },
    [pscustomobject]@{ screenName = "趋势_Trend"; zone = "Trend"; component = "Trend view"; source = "hmi-tag-import-map.csv"; implementation = "Read-only values and historian/logging plan" },
    [pscustomobject]@{ screenName = "参数_Parameter"; zone = "Parameters"; component = "Parameter fields"; source = "tag-contract.md"; implementation = "Authority and range-checked write fields" }
)

$screenCsvPath = Join-Path $OutputDirectory "screen-object-map.csv"
$latestScreenCsvPath = Join-Path $latestDir "screen-object-map.csv"
$screenRows | Export-Csv -LiteralPath $screenCsvPath -NoTypeInformation -Encoding UTF8
$screenRows | Export-Csv -LiteralPath $latestScreenCsvPath -NoTypeInformation -Encoding UTF8

$tagPackagePath = Join-Path $OutputDirectory "hmi-tag-import-map.csv"
$alarmPackagePath = Join-Path $OutputDirectory "alarm-import-map.csv"
$latestTagPackagePath = Join-Path $latestDir "hmi-tag-import-map.csv"
$latestAlarmPackagePath = Join-Path $latestDir "alarm-import-map.csv"
Copy-Item -LiteralPath $tagCsv -Destination $tagPackagePath -Force
Copy-Item -LiteralPath $alarmCsv -Destination $alarmPackagePath -Force
if ($tagCsv -ne $latestTagPackagePath) {
    Copy-Item -LiteralPath $tagCsv -Destination $latestTagPackagePath -Force
}
if ($alarmCsv -ne $latestAlarmPackagePath) {
    Copy-Item -LiteralPath $alarmCsv -Destination $latestAlarmPackagePath -Force
}

$csPath = Join-Path $OutputDirectory "WinccEngineeringSkeleton.cs"
$latestCsPath = Join-Path $latestDir "WinccEngineeringSkeleton.cs"
$cs = New-Object System.Text.StringBuilder
[void]$cs.AppendLine("using System;")
[void]$cs.AppendLine("using System.Diagnostics;")
[void]$cs.AppendLine("using System.IO;")
[void]$cs.AppendLine("using Siemens.Engineering;")
[void]$cs.AppendLine("using Siemens.Engineering.Hmi;")
[void]$cs.AppendLine()
[void]$cs.AppendLine("namespace SiemensTiaSkillSuite.Generated")
[void]$cs.AppendLine("{")
[void]$cs.AppendLine("    public static class WinccEngineeringSkeleton")
[void]$cs.AppendLine("    {")
[void]$cs.AppendLine("        // This adapter delegates the guarded clone operation to the installed PowerShell runner.")
[void]$cs.AppendLine("        public static int ApplyWithRunner(string projectPath, string implementationPath, string hmiDeviceName, bool applyToClone)")
[void]$cs.AppendLine("        {")
[void]$cs.AppendLine("            if (!applyToClone)")
[void]$cs.AppendLine("            {")
[void]$cs.AppendLine("                Console.WriteLine(""Clone-only guard: pass applyToClone=true after review."");")
[void]$cs.AppendLine("                return 2;")
[void]$cs.AppendLine("            }")
[void]$cs.AppendLine("            string runtimeRoot = Environment.GetEnvironmentVariable(""SIEMENS_TIA_RUNTIME_ROOT"");")
[void]$cs.AppendLine("            string runner = String.IsNullOrWhiteSpace(runtimeRoot) ? null : Path.Combine(runtimeRoot, ""skills"", ""siemens-tia-plc-dev"", ""scripts"", ""run-wincc-implementation.ps1"");")
[void]$cs.AppendLine("            if (String.IsNullOrWhiteSpace(runner) || !File.Exists(runner))")
[void]$cs.AppendLine("            {")
[void]$cs.AppendLine("                runner = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "".codex"", ""skills"", ""siemens-tia-plc-dev"", ""scripts"", ""run-wincc-implementation.ps1"");")
[void]$cs.AppendLine("            }")
[void]$cs.AppendLine("            if (!File.Exists(runner))")
[void]$cs.AppendLine("            {")
[void]$cs.AppendLine("                throw new FileNotFoundException(""Installed WinCC implementation runner was not found."", runner);")
[void]$cs.AppendLine("            }")
[void]$cs.AppendLine("            string arguments = ""-NoProfile -ExecutionPolicy Bypass -File "" + Quote(runner) + "" -ProjectPath "" + Quote(projectPath) + "" -ImplementationPath "" + Quote(implementationPath) + "" -ApplyToClone"";")
[void]$cs.AppendLine("            if (!String.IsNullOrWhiteSpace(hmiDeviceName))")
[void]$cs.AppendLine("            {")
[void]$cs.AppendLine("                arguments += "" -HmiDeviceName "" + Quote(hmiDeviceName);")
[void]$cs.AppendLine("            }")
[void]$cs.AppendLine("            ProcessStartInfo start = new ProcessStartInfo(""powershell.exe"", arguments);")
[void]$cs.AppendLine("            start.UseShellExecute = false;")
[void]$cs.AppendLine("            start.CreateNoWindow = true;")
[void]$cs.AppendLine("            start.RedirectStandardOutput = true;")
[void]$cs.AppendLine("            start.RedirectStandardError = true;")
[void]$cs.AppendLine("            using (Process process = Process.Start(start))")
[void]$cs.AppendLine("            {")
[void]$cs.AppendLine("                string stdout = process.StandardOutput.ReadToEnd();")
[void]$cs.AppendLine("                string stderr = process.StandardError.ReadToEnd();")
[void]$cs.AppendLine("                process.WaitForExit();")
[void]$cs.AppendLine("                Console.Write(stdout);")
[void]$cs.AppendLine("                if (!String.IsNullOrEmpty(stderr))")
[void]$cs.AppendLine("                {")
[void]$cs.AppendLine("                    Console.Error.Write(stderr);")
[void]$cs.AppendLine("                }")
[void]$cs.AppendLine("                return process.ExitCode;")
[void]$cs.AppendLine("            }")
[void]$cs.AppendLine("        }")
[void]$cs.AppendLine()
[void]$cs.AppendLine("        private static string Quote(string value)")
[void]$cs.AppendLine("        {")
[void]$cs.AppendLine('            return "\"" + (value ?? String.Empty).Replace("\"", "\\\"") + "\"";')
[void]$cs.AppendLine("        }")
[void]$cs.AppendLine()
[void]$cs.AppendLine("        public static void Apply(TiaPortal tiaPortal, string projectPath, string hmiDeviceName, bool apply)")
[void]$cs.AppendLine("        {")
[void]$cs.AppendLine("            if (!apply)")
[void]$cs.AppendLine("            {")
[void]$cs.AppendLine("                Console.WriteLine(""Dry run only. Add -ApplyToClone in the runner after review."");")
[void]$cs.AppendLine("                return;")
[void]$cs.AppendLine("            }")
[void]$cs.AppendLine("            string projectRoot = Directory.Exists(projectPath) ? projectPath : Path.GetDirectoryName(projectPath);")
[void]$cs.AppendLine("            string implementationPath = Path.Combine(projectRoot, ""PLC_Code"", ""wincc"", ""openness-implementation"", ""latest"");")
[void]$cs.AppendLine("            int exitCode = ApplyWithRunner(projectPath, implementationPath, hmiDeviceName, true);")
[void]$cs.AppendLine("            if (exitCode != 0)")
[void]$cs.AppendLine("            {")
[void]$cs.AppendLine("                throw new InvalidOperationException(""WinCC clone implementation failed with exit code "" + exitCode + ""."");")
[void]$cs.AppendLine("            }")
[void]$cs.AppendLine("        }")
[void]$cs.AppendLine()
[void]$cs.AppendLine("        public static readonly string[] HmiTagPlan = new string[]")
[void]$cs.AppendLine("        {")
foreach ($tag in $tags) {
    $line = ([string]$tag.objectName + " -> " + [string]$tag.tag + " (" + [string]$tag.layer + ", " + [string]$tag.access + ")").Replace("\", "\\").Replace("""", "\""")
    [void]$cs.AppendLine("            """ + $line + """,")
}
[void]$cs.AppendLine("        };")
[void]$cs.AppendLine()
[void]$cs.AppendLine("        public static readonly string[] AlarmPlan = new string[]")
[void]$cs.AppendLine("        {")
foreach ($alarm in $alarms) {
    $line = ([string]$alarm.alarmName + " -> " + [string]$alarm.triggerTag + " (" + [string]$alarm.class + ", ack=" + [string]$alarm.ack + ")").Replace("\", "\\").Replace("""", "\""")
    [void]$cs.AppendLine("            """ + $line + """,")
}
[void]$cs.AppendLine("        };")
[void]$cs.AppendLine("    }")
[void]$cs.AppendLine("}")
$cs.ToString() | Set-Content -LiteralPath $csPath -Encoding UTF8
$cs.ToString() | Set-Content -LiteralPath $latestCsPath -Encoding UTF8

$runnerPath = Join-Path $OutputDirectory "invoke-wincc-openness-implementation.ps1"
$latestRunnerPath = Join-Path $latestDir "invoke-wincc-openness-implementation.ps1"
$runner = @"
param(
    [Parameter(Mandatory = `$true)]
    [string]`$ProjectPath,

    [string]`$HmiDeviceName = "",

    [switch]`$ApplyToClone,

    [string]`$ImplementationPath = ""
)

`$ErrorActionPreference = "Stop"
if (-not `$ApplyToClone) {
    throw "Clone-only guard: pass -ApplyToClone only after preflight and review."
}

if ([string]::IsNullOrWhiteSpace(`$ImplementationPath)) {
    `$ImplementationPath = `$PSScriptRoot
}
`$runtimeRoot = `$env:SIEMENS_TIA_RUNTIME_ROOT
`$implementationScript = ""
if (-not [string]::IsNullOrWhiteSpace(`$runtimeRoot)) {
    `$implementationScript = Join-Path `$runtimeRoot "skills\siemens-tia-plc-dev\scripts\run-wincc-implementation.ps1"
}
if (-not (Test-Path -LiteralPath `$implementationScript -PathType Leaf)) {
    `$implementationScript = Join-Path `$env:USERPROFILE ".codex\skills\siemens-tia-plc-dev\scripts\run-wincc-implementation.ps1"
}
if (-not (Test-Path -LiteralPath `$implementationScript -PathType Leaf)) {
    throw "The installed Siemens TIA skill does not contain the real WinCC implementation runner: `$implementationScript"
}

`$arguments = @(
    "-ProjectPath", `$ProjectPath,
    "-ImplementationPath", `$ImplementationPath,
    "-ApplyToClone"
)
if (-not [string]::IsNullOrWhiteSpace(`$HmiDeviceName)) {
    `$arguments += @("-HmiDeviceName", `$HmiDeviceName)
}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File `$implementationScript @arguments
exit `$LASTEXITCODE
"@
$runner | Set-Content -LiteralPath $runnerPath -Encoding UTF8
$runner | Set-Content -LiteralPath $latestRunnerPath -Encoding UTF8

$manifestItems = New-Object System.Collections.ArrayList
Add-ManifestItem $manifestItems "hmi-tag-import-map" $tagCsv "Reviewed HMI tag import source" "input"
Add-ManifestItem $manifestItems "alarm-import-map" $alarmCsv "Reviewed alarm import source" "input"
Add-ManifestItem $manifestItems "hmi-tag-import-map.package" $tagPackagePath "Packaged HMI tag CSV used by the clone runner" "packaged-input"
Add-ManifestItem $manifestItems "alarm-import-map.package" $alarmPackagePath "Packaged alarm CSV used by the clone runner" "packaged-input"
Add-ManifestItem $manifestItems "screen-object-map" $screenCsvPath "Screen/object implementation mapping" "generated"
Add-ManifestItem $manifestItems "WinccEngineeringSkeleton.cs" $csPath "Reference C# object-model notes for reviewed extensions" "reference"
Add-ManifestItem $manifestItems "invoke-wincc-openness-implementation.ps1" $runnerPath "Clone-only execution wrapper calling the real Openness runner" "generated"

$manifest = [pscustomobject]@{
    schemaVersion = 2
    generatedAt = (Get-Date).ToString("o")
    projectRoot = $root
    workflowConfigPath = $WorkflowConfigPath
    engineeringScaffoldPath = $EngineeringScaffoldPath
    forCloneOnly = $true
    winccFlavor = [string]$scaffold.winccFlavor
    tagCount = $tags.Count
    alarmCount = $alarms.Count
    screenObjectCount = $screenRows.Count
    execution = [pscustomobject]@{
        runner = $runnerPath
        command = "wincc-apply-clone"
        productionWrite = $false
        cloneRequired = $true
        readbackRequired = $true
    }
    items = @($manifestItems)
    releaseAllowed = $false
}
$manifestPath = Join-Path $OutputDirectory "implementation-manifest.json"
$latestManifestPath = Join-Path $latestDir "implementation-manifest.json"
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $latestManifestPath -Encoding UTF8

$readmePath = Join-Path $OutputDirectory "README.md"
$latestReadmePath = Join-Path $latestDir "README.md"
$md = New-Object System.Text.StringBuilder
[void]$md.AppendLine("# WinCC Openness Implementation Package")
[void]$md.AppendLine()
[void]$md.AppendLine("- Project: ``$root``")
[void]$md.AppendLine("- Engineering scaffold: ``$EngineeringScaffoldPath``")
[void]$md.AppendLine("- Clone-only: ``true``")
[void]$md.AppendLine("- HMI tag rows: ``$($tags.Count)``")
[void]$md.AppendLine("- Alarm rows: ``$($alarms.Count)``")
[void]$md.AppendLine("- Screen object rows: ``$($screenRows.Count)``")
[void]$md.AppendLine("- Generated: ``$(Get-Date -Format o)``")
[void]$md.AppendLine()
[void]$md.AppendLine("## Files")
[void]$md.AppendLine()
foreach ($item in $manifestItems) {
    [void]$md.AppendLine("- " + $item.name + ": ``" + $item.path + "``")
}
[void]$md.AppendLine()
[void]$md.AppendLine("## Safety Gate")
[void]$md.AppendLine()
[void]$md.AppendLine("This package contains executable clone-only behavior. The runner creates a project clone, calls the local Openness helper for supported WinCC Unified objects, reads the clone back, and records implementation-run.json. It never writes the production project or downloads to a PLC.")
$md.ToString() | Set-Content -LiteralPath $readmePath -Encoding UTF8
$md.ToString() | Set-Content -LiteralPath $latestReadmePath -Encoding UTF8

[pscustomobject]@{
    status = "ok"
    outputDirectory = $OutputDirectory
    latestDirectory = $latestDir
    readme = $readmePath
    manifest = $manifestPath
    skeleton = $csPath
    tagCount = $tags.Count
    alarmCount = $alarms.Count
    screenObjectCount = $screenRows.Count
    releaseAllowed = $false
} | ConvertTo-Json -Depth 6
