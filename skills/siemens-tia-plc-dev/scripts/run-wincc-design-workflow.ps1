param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    [Parameter(Mandatory = $true)]
    [string]$DesignSpecPath,

    [string]$WorkflowConfigPath = "",
    [string]$ReferenceImagePath = "",
    [switch]$ForCloneOnly
)

$ErrorActionPreference = "Stop"
$utf8Bom = New-Object System.Text.UTF8Encoding($true)
$OutputEncoding = $utf8Bom
[Console]::OutputEncoding = $utf8Bom

function Resolve-ProjectDirectory {
    param([string]$Path)
    $item = Get-Item -LiteralPath $Path
    if ($item.PSIsContainer) { return $item.FullName }
    return $item.Directory.FullName
}

function Get-PropertyValue {
    param(
        [object]$Object,
        [string]$Name,
        [string]$Fallback = ""
    )
    if ($null -eq $Object) { return $Fallback }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) { return $Fallback }
    return $property.Value
}

function Get-ArrayValue {
    param(
        [object]$Object,
        [string]$Name
    )
    $value = Get-PropertyValue -Object $Object -Name $Name -Fallback $null
    if ($null -eq $value) { return @() }
    return @($value)
}

function Write-Utf8Bom {
    param(
        [string]$Path,
        [string]$Content
    )
    $directory = Split-Path -Parent $Path
    if ($directory) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
    [IO.File]::WriteAllText($Path, $Content, $utf8Bom)
}

function Write-JsonCopy {
    param(
        [object]$Object,
        [string[]]$Paths
    )
    $json = $Object | ConvertTo-Json -Depth 12
    foreach ($path in $Paths) { Write-Utf8Bom -Path $path -Content $json }
}

function Invoke-ChildScript {
    param(
        [string]$Path,
        [string[]]$Arguments
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Required WinCC workflow script was not found: $Path"
    }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Path @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "WinCC child workflow failed with exit code ${LASTEXITCODE}: $Path"
    }
}

function CsvValue {
    param([object]$Object, [string]$Name, [string]$Fallback = "")
    return [string](Get-PropertyValue -Object $Object -Name $Name -Fallback $Fallback)
}

function IntValue {
    param([object]$Object, [string]$Name, [int]$Fallback = 0)
    $raw = Get-PropertyValue -Object $Object -Name $Name -Fallback $null
    $number = 0
    if ($null -ne $raw -and [int]::TryParse([string]$raw, [ref]$number)) {
        return $number
    }
    return $Fallback
}

function RectanglesOverlap {
    param([object]$A, [object]$B)
    return (
        ([int]$A.x -lt ([int]$B.x + [int]$B.width)) -and
        (([int]$A.x + [int]$A.width) -gt [int]$B.x) -and
        ([int]$A.y -lt ([int]$B.y + [int]$B.height)) -and
        (([int]$A.y + [int]$A.height) -gt [int]$B.y)
    )
}

$root = Resolve-ProjectDirectory -Path $ProjectPath
$workspaceRoot = Join-Path $root "PLC_Code"
if ([string]::IsNullOrWhiteSpace($WorkflowConfigPath)) {
    $WorkflowConfigPath = Join-Path $workspaceRoot "config\ai-workflow.json"
}
if (-not (Test-Path -LiteralPath $DesignSpecPath -PathType Leaf)) {
    throw "WinCC design specification was not found: $DesignSpecPath"
}

$spec = Get-Content -LiteralPath $DesignSpecPath -Raw -Encoding UTF8 | ConvertFrom-Json
$screens = Get-ArrayValue -Object $spec -Name "screens"
$components = Get-ArrayValue -Object $spec -Name "components"
$tags = Get-ArrayValue -Object $spec -Name "tags"
$alarms = Get-ArrayValue -Object $spec -Name "alarms"
if ($screens.Count -eq 0) { throw "Design specification must contain at least one screen." }
if ($components.Count -eq 0) { throw "Design specification must contain at least one component." }

$taskText = [string](Get-PropertyValue -Object $spec -Name "taskText" -Fallback "Build an editable WinCC design")
if ([string]::IsNullOrWhiteSpace($ReferenceImagePath)) {
    $ReferenceImagePath = [string](Get-PropertyValue -Object (Get-PropertyValue -Object $spec -Name "referenceImage" -Fallback $null) -Name "path" -Fallback "")
}
if ([string]::IsNullOrWhiteSpace($ReferenceImagePath)) {
    $ReferenceImagePath = ""
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$runRoot = Join-Path $workspaceRoot ("wincc\design-workflow\" + $stamp)
$latestRoot = Join-Path $workspaceRoot "wincc\design-workflow\latest"
New-Item -ItemType Directory -Path $runRoot, $latestRoot -Force | Out-Null

$skillsRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$winccScriptsRoot = Join-Path $skillsRoot "siemens-wincc-hmi-dev\scripts"
$visualScript = Join-Path $winccScriptsRoot "scaffold-wincc-visual-package.ps1"
$blueprintScript = Join-Path $winccScriptsRoot "scaffold-wincc-component-blueprints.ps1"
$engineeringScript = Join-Path $winccScriptsRoot "scaffold-wincc-engineering-package.ps1"
$implementationScript = Join-Path $winccScriptsRoot "scaffold-wincc-openness-implementation.ps1"

$commonArgs = @("-ProjectPath", $root, "-WorkflowConfigPath", $WorkflowConfigPath, "-TaskText", $taskText)
if (-not [string]::IsNullOrWhiteSpace($ReferenceImagePath) -and (Test-Path -LiteralPath $ReferenceImagePath -PathType Leaf)) {
    $commonArgs += @("-ReferenceImagePath", (Get-Item -LiteralPath $ReferenceImagePath).FullName)
}

# Generate the standard handoff layers first. The explicit design specification
# is overlaid below so the downstream packages consume the user's structure.
Invoke-ChildScript -Path $visualScript -Arguments $commonArgs
Invoke-ChildScript -Path $blueprintScript -Arguments $commonArgs
Invoke-ChildScript -Path $engineeringScript -Arguments $commonArgs

$visualLatest = Join-Path $workspaceRoot "wincc\tasks\latest"
$blueprintLatest = Join-Path $workspaceRoot "wincc\component-blueprints\latest"
$engineeringLatest = Join-Path $workspaceRoot "wincc\engineering-scaffold\latest"
$implementationLatest = Join-Path $workspaceRoot "wincc\openness-implementation\latest"

$screenMap = New-Object System.Text.StringBuilder
[void]$screenMap.AppendLine("# WinCC Screen Map")
[void]$screenMap.AppendLine()
[void]$screenMap.AppendLine("- Source: ``$DesignSpecPath``")
[void]$screenMap.AppendLine("- Task: $taskText")
[void]$screenMap.AppendLine()
[void]$screenMap.AppendLine("| Screen | Purpose | Zone |")
[void]$screenMap.AppendLine("| --- | --- | --- |")
foreach ($screen in $screens) {
    [void]$screenMap.AppendLine("| $(CsvValue $screen "name") | $(CsvValue $screen "purpose") | $(CsvValue $screen "zone" "MainContent") |")
}

$componentMap = New-Object System.Text.StringBuilder
[void]$componentMap.AppendLine("# WinCC Component Map")
[void]$componentMap.AppendLine()
[void]$componentMap.AppendLine("- Source: ``$DesignSpecPath``")
[void]$componentMap.AppendLine()
[void]$componentMap.AppendLine("| Component | Type | Screen | Tags |")
[void]$componentMap.AppendLine("| --- | --- | --- | --- |")
foreach ($component in $components) {
    [void]$componentMap.AppendLine("| $(CsvValue $component "name") | $(CsvValue $component "type") | $(CsvValue $component "screen") | $(CsvValue $component "tags") |")
}

$tagContract = New-Object System.Text.StringBuilder
[void]$tagContract.AppendLine("# PLC-HMI Tag Contract")
[void]$tagContract.AppendLine()
[void]$tagContract.AppendLine("- Source: ``$DesignSpecPath``")
[void]$tagContract.AppendLine("- Naming: ``Chinese_English``")
[void]$tagContract.AppendLine()
[void]$tagContract.AppendLine("| Object | Tag | Layer | Access |")
[void]$tagContract.AppendLine("| --- | --- | --- | --- |")
foreach ($tag in $tags) {
    [void]$tagContract.AppendLine("| $(CsvValue $tag "objectName") | $(CsvValue $tag "tag") | $(CsvValue $tag "layer") | $(CsvValue $tag "access") |")
}

$safetyReview = @"
# WinCC Safety Review

- Commands and feedback use separate tags.
- Reset, homing, recipe write and force-like actions require authority and confirmation.
- Alarm acknowledgement does not clear the physical fault.
- The first Openness/SiVArc generation target is a clone.
- Production project write and PLC download remain disabled by this workflow.
"@

$style = Get-PropertyValue -Object $spec -Name "style" -Fallback $null
$styleGuide = @"
# WinCC Style Guide

- Palette: $(CsvValue $style "palette" "soft-industrial-gradient")
- Naming: $(CsvValue $style "naming" "Chinese_English")
- Command confirmation: $(CsvValue $style "commandConfirmation" "true")
- Use stable navigation and a permanently visible alarm/status strip.
- Rebuild reference images with editable WinCC objects, faceplates or SiVArc rules.
"@

foreach ($target in @(
    (Join-Path $runRoot "screen-map.md"),
    (Join-Path $latestRoot "screen-map.md"),
    (Join-Path $visualLatest "screen-map.md")
)) { Write-Utf8Bom -Path $target -Content $screenMap.ToString() }
foreach ($target in @(
    (Join-Path $runRoot "component-map.md"),
    (Join-Path $latestRoot "component-map.md"),
    (Join-Path $visualLatest "component-map.md")
)) { Write-Utf8Bom -Path $target -Content $componentMap.ToString() }
foreach ($target in @(
    (Join-Path $runRoot "tag-contract.md"),
    (Join-Path $latestRoot "tag-contract.md"),
    (Join-Path $visualLatest "tag-contract.md")
)) { Write-Utf8Bom -Path $target -Content $tagContract.ToString() }
foreach ($target in @(
    (Join-Path $runRoot "safety-review.md"),
    (Join-Path $latestRoot "safety-review.md"),
    (Join-Path $visualLatest "safety-review.md")
)) { Write-Utf8Bom -Path $target -Content $safetyReview }
foreach ($target in @(
    (Join-Path $runRoot "style-guide.md"),
    (Join-Path $latestRoot "style-guide.md"),
    (Join-Path $visualLatest "style-guide.md")
)) { Write-Utf8Bom -Path $target -Content $styleGuide }

Write-JsonCopy -Object $spec -Paths @(
    (Join-Path $runRoot "design-spec.json"),
    (Join-Path $latestRoot "design-spec.json"),
    (Join-Path $visualLatest "design-spec.json"),
    (Join-Path $engineeringLatest "design-spec.json"),
    (Join-Path $implementationLatest "design-spec.json")
)

$tagRows = foreach ($tag in $tags) {
    [pscustomobject]@{
        objectName = CsvValue $tag "objectName"
        tag = CsvValue $tag "tag"
        layer = CsvValue $tag "layer"
        access = CsvValue $tag "access" "read"
        confirmation = CsvValue $tag "confirmation"
        note = CsvValue $tag "note"
    }
}
$alarmRows = foreach ($alarm in $alarms) {
    [pscustomobject]@{
        alarmName = CsvValue $alarm "alarmName"
        class = CsvValue $alarm "class" "Fault"
        triggerTag = CsvValue $alarm "triggerTag"
        ack = CsvValue $alarm "ack" "required"
        reset = CsvValue $alarm "reset" "separate-reset-command"
    }
}
$screenSize = Get-PropertyValue -Object $spec -Name "screenSize" -Fallback $null
$width = [int](Get-PropertyValue -Object $screenSize -Name "width" -Fallback 1920)
$height = [int](Get-PropertyValue -Object $screenSize -Name "height" -Fallback 1080)
$screenRows = foreach ($screen in $screens) {
    $screenName = CsvValue $screen "name"
    $matching = @($components | Where-Object { (CsvValue $_ "screen") -eq $screenName })
    if ($matching.Count -eq 0) {
        [pscustomobject]@{
            screenName = $screenName
            zone = CsvValue $screen "zone" "MainContent"
            component = "ScreenShell"
            type = "screen-shell"
            tags = ""
            x = 0
            y = 0
            width = $width
            height = $height
            source = "design-spec.json"
            implementation = "WinCC native screen, faceplate or SiVArc rule"
        }
        continue
    }
    foreach ($component in $matching) {
        [pscustomobject]@{
            screenName = $screenName
            zone = CsvValue $screen "zone" "MainContent"
            component = CsvValue $component "name"
            type = CsvValue $component "type" "standard-control"
            tags = CsvValue $component "tags"
            x = [int](Get-PropertyValue -Object $component -Name "x" -Fallback 0)
            y = [int](Get-PropertyValue -Object $component -Name "y" -Fallback 0)
            width = [int](Get-PropertyValue -Object $component -Name "width" -Fallback 0)
            height = [int](Get-PropertyValue -Object $component -Name "height" -Fallback 0)
            source = "design-spec.json"
            implementation = "WinCC native screen, faceplate or SiVArc rule"
        }
    }
}

# Keep geometry validation independent from Openness so clone-only design checks remain deterministic.
$geometryRows = foreach ($component in $components) {
    [pscustomobject]@{
        screen = CsvValue $component "screen"
        component = CsvValue $component "name"
        x = IntValue $component "x" 0
        y = IntValue $component "y" 0
        width = IntValue $component "width" 0
        height = IntValue $component "height" 0
    }
}
$layoutIssues = New-Object System.Collections.ArrayList
foreach ($row in $geometryRows) {
    if ($row.width -le 0 -or $row.height -le 0) {
        [void]$layoutIssues.Add([pscustomobject]@{
            severity = "warning"
            code = "missing-size"
            screen = $row.screen
            component = $row.component
            relatedComponent = ""
            message = "组件缺少有效 width/height，无法进行遮挡校验。"
        })
        continue
    }
    if ($row.x -lt 0 -or $row.y -lt 0 -or ($row.x + $row.width) -gt $width -or ($row.y + $row.height) -gt $height) {
        [void]$layoutIssues.Add([pscustomobject]@{
            severity = "error"
            code = "out-of-bounds"
            screen = $row.screen
            component = $row.component
            relatedComponent = ""
            message = "组件超出画面边界 ${width}x${height}。"
        })
    }
}
foreach ($screen in $screens) {
    $screenName = CsvValue $screen "name"
    $screenComponents = @($geometryRows | Where-Object { $_.screen -eq $screenName -and $_.width -gt 0 -and $_.height -gt 0 })
    for ($i = 0; $i -lt $screenComponents.Count; $i++) {
        for ($j = $i + 1; $j -lt $screenComponents.Count; $j++) {
            if (RectanglesOverlap -A $screenComponents[$i] -B $screenComponents[$j]) {
                [void]$layoutIssues.Add([pscustomobject]@{
                    severity = "error"
                    code = "overlap"
                    screen = $screenName
                    component = $screenComponents[$i].component
                    relatedComponent = $screenComponents[$j].component
                    message = "组件矩形相交，可能造成界面遮挡。"
                })
            }
        }
    }
}
$layoutStatus = if (@($layoutIssues | Where-Object { $_.severity -eq "error" }).Count -gt 0) { "REVIEW_REQUIRED" } else { "PASS" }
$layoutValidation = [pscustomobject]@{
    schemaVersion = 1
    source = "design-spec.json"
    screenSize = [pscustomobject]@{ width = $width; height = $height }
    status = $layoutStatus
    componentCount = $components.Count
    issueCount = $layoutIssues.Count
    overlapCount = @($layoutIssues | Where-Object { $_.code -eq "overlap" }).Count
    outOfBoundsCount = @($layoutIssues | Where-Object { $_.code -eq "out-of-bounds" }).Count
    incompleteGeometryCount = @($layoutIssues | Where-Object { $_.code -eq "missing-size" }).Count
    issues = @($layoutIssues)
}
$layoutValidationMdBuilder = New-Object System.Text.StringBuilder
[void]$layoutValidationMdBuilder.AppendLine("# WinCC Layout Validation")
[void]$layoutValidationMdBuilder.AppendLine()
[void]$layoutValidationMdBuilder.AppendLine("- Source: ``$DesignSpecPath``")
[void]$layoutValidationMdBuilder.AppendLine("- Screen size: ``${width}x${height}``")
[void]$layoutValidationMdBuilder.AppendLine("- Status: ``$layoutStatus``")
[void]$layoutValidationMdBuilder.AppendLine("- Components: ``$($components.Count)``")
[void]$layoutValidationMdBuilder.AppendLine("- Overlaps: ``$($layoutValidation.overlapCount)``")
[void]$layoutValidationMdBuilder.AppendLine("- Out of bounds: ``$($layoutValidation.outOfBoundsCount)``")
[void]$layoutValidationMdBuilder.AppendLine("- Missing size: ``$($layoutValidation.incompleteGeometryCount)``")
[void]$layoutValidationMdBuilder.AppendLine()
[void]$layoutValidationMdBuilder.AppendLine("| Severity | Code | Screen | Component | Related | Message |")
[void]$layoutValidationMdBuilder.AppendLine("| --- | --- | --- | --- | --- | --- |")
if ($layoutIssues.Count -eq 0) {
    [void]$layoutValidationMdBuilder.AppendLine("| pass | none | - | - | - | 未发现组件重叠、越界或尺寸缺失。 |")
}
else {
    foreach ($issue in $layoutIssues) {
        [void]$layoutValidationMdBuilder.AppendLine("| $($issue.severity) | $($issue.code) | $($issue.screen) | $($issue.component) | $($issue.relatedComponent) | $($issue.message) |")
    }
}

Write-JsonCopy -Object $layoutValidation -Paths @(
    (Join-Path $runRoot "layout-validation.json"),
    (Join-Path $latestRoot "layout-validation.json"),
    (Join-Path $visualLatest "layout-validation.json"),
    (Join-Path $engineeringLatest "layout-validation.json"),
    (Join-Path $implementationLatest "layout-validation.json")
)
foreach ($target in @(
    (Join-Path $runRoot "layout-validation.md"),
    (Join-Path $latestRoot "layout-validation.md"),
    (Join-Path $visualLatest "layout-validation.md"),
    (Join-Path $engineeringLatest "layout-validation.md"),
    (Join-Path $implementationLatest "layout-validation.md")
)) {
    Write-Utf8Bom -Path $target -Content $layoutValidationMdBuilder.ToString()
}

foreach ($dir in @($runRoot, $latestRoot, $engineeringLatest, $implementationLatest)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}
foreach ($path in @(
    (Join-Path $runRoot "hmi-tag-import-map.csv"),
    (Join-Path $latestRoot "hmi-tag-import-map.csv"),
    (Join-Path $engineeringLatest "hmi-tag-import-map.csv"),
    (Join-Path $implementationLatest "hmi-tag-import-map.csv")
)) { @($tagRows) | Export-Csv -LiteralPath $path -NoTypeInformation -Encoding UTF8 }
foreach ($path in @(
    (Join-Path $runRoot "alarm-import-map.csv"),
    (Join-Path $latestRoot "alarm-import-map.csv"),
    (Join-Path $engineeringLatest "alarm-import-map.csv"),
    (Join-Path $implementationLatest "alarm-import-map.csv")
)) { @($alarmRows) | Export-Csv -LiteralPath $path -NoTypeInformation -Encoding UTF8 }
foreach ($path in @(
    (Join-Path $runRoot "screen-object-map.csv"),
    (Join-Path $latestRoot "screen-object-map.csv"),
    (Join-Path $implementationLatest "screen-object-map.csv")
)) { @($screenRows) | Export-Csv -LiteralPath $path -NoTypeInformation -Encoding UTF8 }

$zones = Get-ArrayValue -Object $spec -Name "zones"
if ($zones.Count -eq 0) {
    $zones = @(
        [pscustomobject]@{ id = "header"; name = "顶部状态_Header"; x = 0; y = 0; w = $width; h = 92 },
        [pscustomobject]@{ id = "alarm"; name = "报警条_AlarmStrip"; x = 0; y = 92; w = $width; h = 58 },
        [pscustomobject]@{ id = "nav"; name = "导航_Navigation"; x = 0; y = 150; w = 250; h = $height - 150 },
        [pscustomobject]@{ id = "content"; name = "主内容_MainContent"; x = 250; y = 150; w = $width - 250; h = $height - 150 }
    )
}
$layout = [pscustomobject]@{
    schemaVersion = 1
    source = "design-spec.json"
    screenSize = [pscustomobject]@{ width = $width; height = $height }
    zones = @($zones)
    screens = @($screens)
    components = @($components)
    validation = $layoutValidation
    spacing = [int](Get-PropertyValue -Object $spec -Name "spacing" -Fallback 18)
    cornerRadius = [int](Get-PropertyValue -Object $spec -Name "cornerRadius" -Fallback 14)
}
Write-JsonCopy -Object $layout -Paths @(
    (Join-Path $runRoot "screen-layout-grid.json"),
    (Join-Path $latestRoot "screen-layout-grid.json"),
    (Join-Path $blueprintLatest "screen-layout-grid.json")
)

if (Test-Path -LiteralPath $implementationScript -PathType Leaf) {
    $implementationArgs = @("-ProjectPath", $root, "-EngineeringScaffoldPath", (Join-Path $workspaceRoot "wincc\engineering-scaffold\latest\wincc-engineering-scaffold.json"), "-ForCloneOnly")
    Invoke-ChildScript -Path $implementationScript -Arguments $implementationArgs
    @($screenRows) | Export-Csv -LiteralPath (Join-Path $implementationLatest "screen-object-map.csv") -NoTypeInformation -Encoding UTF8
    @($tagRows) | Export-Csv -LiteralPath (Join-Path $implementationLatest "hmi-tag-import-map.csv") -NoTypeInformation -Encoding UTF8
    @($alarmRows) | Export-Csv -LiteralPath (Join-Path $implementationLatest "alarm-import-map.csv") -NoTypeInformation -Encoding UTF8

    $implementationManifestPath = Join-Path $implementationLatest "implementation-manifest.json"
    if (Test-Path -LiteralPath $implementationManifestPath -PathType Leaf) {
        $implementationManifest = Get-Content -LiteralPath $implementationManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $implementationManifest | Add-Member -MemberType NoteProperty -Name "designSpecPath" -Value (Get-Item -LiteralPath $DesignSpecPath).FullName -Force
        $implementationManifest | Add-Member -MemberType NoteProperty -Name "designScreenCount" -Value $screens.Count -Force
        $implementationManifest | Add-Member -MemberType NoteProperty -Name "designComponentCount" -Value $components.Count -Force
        $implementationManifest | Add-Member -MemberType NoteProperty -Name "screenObjectCount" -Value $screenRows.Count -Force
        $implementationManifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $implementationManifestPath -Encoding UTF8
    }
}

$engineeringManifestPath = Join-Path $engineeringLatest "wincc-engineering-scaffold.json"
if (Test-Path -LiteralPath $engineeringManifestPath -PathType Leaf) {
    $engineeringManifest = Get-Content -LiteralPath $engineeringManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $engineeringManifest | Add-Member -MemberType NoteProperty -Name "designSpecPath" -Value (Get-Item -LiteralPath $DesignSpecPath).FullName -Force
    $engineeringManifest | Add-Member -MemberType NoteProperty -Name "designScreenCount" -Value $screens.Count -Force
    $engineeringManifest | Add-Member -MemberType NoteProperty -Name "designComponentCount" -Value $components.Count -Force
    if ($null -eq $engineeringManifest.inputs) {
        $engineeringManifest | Add-Member -MemberType NoteProperty -Name "inputs" -Value ([pscustomobject]@{}) -Force
    }
    $engineeringManifest.inputs | Add-Member -MemberType NoteProperty -Name "designSpec" -Value (Join-Path $engineeringLatest "design-spec.json") -Force
    $engineeringManifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $engineeringManifestPath -Encoding UTF8
}

$report = [pscustomobject]@{
    status = "ok"
    projectRoot = $root
    designSpecPath = (Get-Item -LiteralPath $DesignSpecPath).FullName
    runRoot = $runRoot
    latestRoot = $latestRoot
    screenCount = $screens.Count
    componentCount = $components.Count
    tagCount = $tags.Count
    alarmCount = $alarms.Count
    standardPackages = [pscustomobject]@{
        visualPackage = (Join-Path $visualLatest "README.md")
        componentBlueprints = (Join-Path $blueprintLatest "component-blueprints.json")
        engineeringScaffold = (Join-Path $engineeringLatest "wincc-engineering-scaffold.json")
        opennessImplementation = (Join-Path $implementationLatest "implementation-manifest.json")
        layoutValidation = (Join-Path $latestRoot "layout-validation.json")
    }
    forCloneOnly = $true
    productionWrite = $false
    plcDownload = $false
    layoutStatus = $layoutStatus
    layoutIssueCount = $layoutIssues.Count
    layoutOverlapCount = $layoutValidation.overlapCount
    layoutOutOfBoundsCount = $layoutValidation.outOfBoundsCount
}
Write-JsonCopy -Object $report -Paths @(
    (Join-Path $runRoot "workflow-report.json"),
    (Join-Path $latestRoot "workflow-report.json")
)

$reportMd = @"
# WinCC Design Workflow

- Project: ``$root``
- Design spec: ``$DesignSpecPath``
- Screens: ``$($screens.Count)``
- Components: ``$($components.Count)``
- HMI tags: ``$($tags.Count)``
- Alarms: ``$($alarms.Count)``
- Layout status: ``$layoutStatus``
- Layout overlaps: ``$($layoutValidation.overlapCount)``
- Layout out of bounds: ``$($layoutValidation.outOfBoundsCount)``
- Clone only: ``true``
- Production write: ``false``
- PLC download: ``false``

The workbench compiled the user-editable design specification into WinCC visual,
component, engineering and clone-only implementation handoff artifacts.
"@
Write-Utf8Bom -Path (Join-Path $runRoot "workflow-report.md") -Content $reportMd
Write-Utf8Bom -Path (Join-Path $latestRoot "workflow-report.md") -Content $reportMd

$report | ConvertTo-Json -Depth 8
