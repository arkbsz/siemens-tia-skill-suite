param(
    [string]$ScriptPath = (Join-Path $PSScriptRoot "resolve-wincc-bindings.ps1")
)

$ErrorActionPreference = "Stop"
$nativeUtf8 = New-Object System.Text.UTF8Encoding($false)
$OutputEncoding = $nativeUtf8
[Console]::OutputEncoding = $nativeUtf8

$testRoot = Join-Path ([IO.Path]::GetTempPath()) ("wincc-binding-test-" + [guid]::NewGuid().ToString("N"))
$projectRoot = Join-Path $testRoot "project"
$workspaceRoot = Join-Path $projectRoot "PLC_Code"
$contractRoot = Join-Path $workspaceRoot "engineering-contracts\latest"
$packageRoot = Join-Path $workspaceRoot "wincc\engineering-scaffold\latest"
$outputRoot = Join-Path $workspaceRoot "wincc\binding-review\latest"
$reviewPath = Join-Path $outputRoot "binding-review.csv"

New-Item -ItemType Directory -Path $contractRoot, $packageRoot -Force | Out-Null
Set-Content -LiteralPath (Join-Path $projectRoot "fixture.ap17") -Value "" -Encoding UTF8
Set-Content -LiteralPath (Join-Path $workspaceRoot "config.json") -Value "{}" -Encoding UTF8

try {
    $report = [pscustomobject]@{
        dbMembers = @(
            [pscustomobject]@{ dbName = "状态数据_StateData"; memberPath = "速度设定_SpeedSp"; datatype = "Real"; writable = $true; sourceXml = "db.xml" }
            [pscustomobject]@{ dbName = "状态数据_StateData"; memberPath = "运行反馈_RunFb"; datatype = "Bool"; writable = $true; sourceXml = "db.xml" }
            [pscustomobject]@{ dbName = "报警数据_AlarmData"; memberPath = "总故障_TotalFault"; datatype = "Bool"; writable = $true; sourceXml = "alarm.xml" }
        )
        ladReferences = @(
            [pscustomobject]@{ referenceType = "GLOBAL_SYMBOL"; symbolPath = "启动_Start" ; sourceXml = "main.xml" }
            [pscustomobject]@{ referenceType = "GLOBAL_SYMBOL"; symbolPath = "停止_Stop" ; sourceXml = "main.xml" }
        )
    }
    $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $contractRoot "engineering-contract-report.json") -Encoding UTF8

    @"
"objectName","tag","layer","access","confirmation","source"
"BTN_启动_Start","启动命令_StartCmd","Cmd","write","mode-authority","design-spec.json"
"IO_速度_Speed","速度设定_SpeedSp","Par","write","authority-and-range","design-spec.json"
"IND_运行_Run","运行反馈_RunFb","Fb","read","","design-spec.json"
"@ | Set-Content -LiteralPath (Join-Path $packageRoot "hmi-tag-import-map.csv") -Encoding UTF8

    @"
"alarmName","class","triggerTag","ack","reset","source"
"总故障_TotalFault","Fault","总故障_ActiveAlarm","required","separate-reset-command","design-spec.json"
"@ | Set-Content -LiteralPath (Join-Path $packageRoot "alarm-import-map.csv") -Encoding UTF8

    $json = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ScriptPath `
        -ProjectPath $projectRoot -ContractReportPath (Join-Path $contractRoot "engineering-contract-report.json") `
        -WinccPackagePath $packageRoot -OutputDirectory $outputRoot `
        -WorkflowConfigPath (Join-Path $workspaceRoot "config.json")
    if ($LASTEXITCODE -ne 0) { throw "Binding assistant generation failed." }
    $result = ($json | Out-String).Trim() | ConvertFrom-Json
    if ([int]$result.reviewCount -ne 4) { throw "Expected four review rows." }
    $candidateText = Get-Content -Raw -Encoding UTF8 (Join-Path $outputRoot "binding-candidates.csv")
    if ($candidateText -notmatch "启动_Start" -or $candidateText -notmatch "状态数据_StateData.速度设定_SpeedSp") {
        throw "Expected semantic candidates were not generated."
    }
    if ($candidateText -match "design-spec\.json") {
        throw "Design source metadata was incorrectly treated as a PLC binding candidate."
    }

    $reviewRows = @(Import-Csv -LiteralPath $reviewPath -Encoding UTF8)
    foreach ($row in $reviewRows) {
        $row.decision = "approve"
        if ([string]$row.objectType -eq "HMI_TAG" -and [string]$row.objectName -eq "BTN_启动_Start") {
            $row.selectedBinding = "启动_Start"
        }
        elseif ([string]$row.objectType -eq "HMI_TAG" -and [string]$row.objectName -eq "IO_速度_Speed") {
            $row.selectedBinding = "状态数据_StateData.速度设定_SpeedSp"
        }
        elseif ([string]$row.objectType -eq "HMI_TAG" -and [string]$row.objectName -eq "IND_运行_Run") {
            $row.selectedBinding = "状态数据_StateData.运行反馈_RunFb"
        }
        elseif ([string]$row.objectType -eq "ALARM") {
            $row.selectedBinding = "报警数据_AlarmData.总故障_TotalFault"
        }
    }
    @($reviewRows) | Export-Csv -LiteralPath $reviewPath -NoTypeInformation -Encoding UTF8
    $applyJson = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ScriptPath `
        -ProjectPath $projectRoot -ContractReportPath (Join-Path $contractRoot "engineering-contract-report.json") `
        -WinccPackagePath $packageRoot -OutputDirectory $outputRoot -ApplyReviewPath $reviewPath
    if ($LASTEXITCODE -ne 0) { throw "Binding assistant apply failed." }
    $appliedTags = Import-Csv -LiteralPath (Join-Path $outputRoot "applied\hmi-tag-import-map.csv") -Encoding UTF8
    if ((@($appliedTags | Where-Object { -not [string]::IsNullOrWhiteSpace($_.plcPath) }).Count) -ne 3) {
        throw "Derived HMI map did not receive all approved bindings."
    }

    [pscustomobject]@{
        status = "passed"
        reviewCount = $result.reviewCount
        candidateCount = $result.plcCandidateCount
        appliedTagCount = @($appliedTags | Where-Object { $_.plcPath }).Count
        outputDirectory = $outputRoot
    } | ConvertTo-Json -Depth 8
}
finally {
    $resolvedTestRoot = [IO.Path]::GetFullPath($testRoot)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolvedTestRoot.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path -Leaf $resolvedTestRoot) -like "wincc-binding-test-*") {
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
