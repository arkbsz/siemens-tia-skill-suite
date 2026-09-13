param(
    [string]$AnalyzerPath = (Join-Path $PSScriptRoot "analyze-engineering-contracts.ps1")
)

$ErrorActionPreference = "Stop"
$nativeUtf8 = New-Object System.Text.UTF8Encoding($false)
$OutputEncoding = $nativeUtf8
[Console]::OutputEncoding = $nativeUtf8

if (-not (Test-Path -LiteralPath $AnalyzerPath -PathType Leaf)) {
    throw "Engineering contract analyzer was not found: $AnalyzerPath"
}

$testRoot = Join-Path ([IO.Path]::GetTempPath()) ("engineering-contract-test-" + [guid]::NewGuid().ToString("N"))
$projectRoot = Join-Path $testRoot "project"
$workspaceRoot = Join-Path $projectRoot "PLC_Code"
$exportRoot = Join-Path $workspaceRoot "exports"
$winccRoot = Join-Path $workspaceRoot "wincc"
$runRoot = Join-Path $workspaceRoot "runs\read-cycle-test\reports"
$validOutput = Join-Path $testRoot "valid-output"
$blockOnlyExport = Join-Path $testRoot "block-only-export"
$blockOnlyOutput = Join-Path $testRoot "block-only-output"
$missingOutput = Join-Path $testRoot "missing-output"

New-Item -ItemType Directory -Path $exportRoot, $winccRoot, $runRoot, $blockOnlyExport -Force | Out-Null
Set-Content -LiteralPath (Join-Path $projectRoot "fixture.ap17") -Value "" -Encoding UTF8

try {
    @"
STARTING`tTIA Portal`tMode=WithoutUserInterface
Name`tType`tNumber`tLanguage`tGroup`tConsistent`tKnowHowProtected
主逻辑_MainLogic`tFC`t1`tLAD`t`tTrue`tFalse
状态数据_StateData`tGlobalDB`t1`tDB`t`tTrue`tFalse
"@ | Set-Content -LiteralPath (Join-Path $runRoot "block-list.txt") -Encoding UTF8

    @"
<?xml version="1.0" encoding="utf-8"?>
<Document>
  <Engineering version="V17" />
  <SW.Blocks.GlobalDB ID="0">
    <AttributeList>
      <Name>状态数据_StateData</Name>
      <Number>1</Number>
      <ProgrammingLanguage>DB</ProgrammingLanguage>
      <Interface>
        <Sections xmlns="http://www.siemens.com/automation/Openness/SW/Interface/v5">
          <Section Name="Static">
            <Member Name="运行反馈_RunFb" Datatype="Bool" Accessibility="Public" />
            <Member Name="启动命令_StartCmd" Datatype="Bool" Accessibility="Public" />
            <Member Name="故障报警_FaultAlm" Datatype="Bool" Accessibility="Public" />
          </Section>
        </Sections>
      </Interface>
    </AttributeList>
  </SW.Blocks.GlobalDB>
</Document>
"@ | Set-Content -LiteralPath (Join-Path $exportRoot "state-db.xml") -Encoding UTF8

    @"
<?xml version="1.0" encoding="utf-8"?>
<Document>
  <Engineering version="V17" />
  <SW.Blocks.FC ID="0">
    <AttributeList>
      <Name>主逻辑_MainLogic</Name>
      <Number>1</Number>
      <ProgrammingLanguage>LAD</ProgrammingLanguage>
    </AttributeList>
    <ObjectList>
      <SW.Blocks.CompileUnit ID="1">
        <AttributeList>
          <NetworkSource>
            <FlgNet xmlns="http://www.siemens.com/automation/Openness/SW/NetworkSource/FlgNet/v4">
              <Parts>
                <Access Scope="GlobalVariable" UId="1">
                  <Symbol>
                    <Component Name="状态数据_StateData" />
                    <Component Name="启动命令_StartCmd" />
                  </Symbol>
                </Access>
                <Access Scope="GlobalVariable" UId="2">
                  <Symbol>
                    <Component Name="状态数据_StateData" />
                    <Component Name="运行反馈_RunFb" />
                  </Symbol>
                </Access>
                <Part Name="Contact" UId="3" />
              </Parts>
              <Wires />
            </FlgNet>
          </NetworkSource>
        </AttributeList>
      </SW.Blocks.CompileUnit>
    </ObjectList>
  </SW.Blocks.FC>
</Document>
"@ | Set-Content -LiteralPath (Join-Path $exportRoot "main.xml") -Encoding UTF8

    @"
"objectName","tag","layer","access","confirmation","note"
"BTN_启动_Start","状态数据_StateData.启动命令_StartCmd","Cmd","write","mode-authority","command"
"IND_运行_Run","状态数据_StateData.运行反馈_RunFb","Fb","read","","feedback"
"ALM_故障_Fault","状态数据_StateData.故障报警_FaultAlm","Alm","read","","alarm"
"@ | Set-Content -LiteralPath (Join-Path $winccRoot "hmi-tag-import-map.csv") -Encoding UTF8

    @"
"alarmName","class","triggerTag","ack","reset"
"故障报警_FaultAlm","Fault","状态数据_StateData.故障报警_FaultAlm","required","separate-reset-command"
"@ | Set-Content -LiteralPath (Join-Path $winccRoot "alarm-import-map.csv") -Encoding UTF8

    @"
"screenName","zone","component","source","implementation","tags"
"总览_Overview","Content","状态卡_StsCard","fixture","native","状态数据_StateData.运行反馈_RunFb"
"@ | Set-Content -LiteralPath (Join-Path $winccRoot "screen-object-map.csv") -Encoding UTF8

    $validJson = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $AnalyzerPath `
        -ProjectPath $projectRoot -ExportRoot $exportRoot -WinccPackagePath $winccRoot -OutputDirectory $validOutput
    if ($LASTEXITCODE -ne 0) { throw "Valid contract fixture execution failed." }
    $valid = ($validJson | Out-String).Trim() | ConvertFrom-Json
    if ($valid.contractStatus -eq "FAIL") {
        throw "Valid contract fixture unexpectedly failed."
    }
    if ([int]$valid.counts.dbMembers -lt 3 -or [int]$valid.counts.ladReferences -lt 3) {
        throw "Valid contract fixture did not index DB members and LAD references."
    }

    Copy-Item -LiteralPath (Join-Path $exportRoot "main.xml") `
        -Destination (Join-Path $blockOnlyExport "main.xml") -Force
    $blockOnlyJson = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $AnalyzerPath `
        -ProjectPath $projectRoot -ExportRoot $blockOnlyExport -OutputDirectory $blockOnlyOutput
    if ($LASTEXITCODE -ne 0) { throw "Block-only contract fixture execution failed." }
    $blockOnly = ($blockOnlyJson | Out-String).Trim() | ConvertFrom-Json
    if ($blockOnly.contractStatus -ne "WARN") {
        throw "Block-only DB evidence fixture was not classified as WARN."
    }
    $blockOnlyReport = Get-Content -LiteralPath $blockOnly.reportJson -Raw -Encoding UTF8 | ConvertFrom-Json
    if (@($blockOnlyReport.findings | Where-Object { $_.code -eq "MISSING_DB_MEMBER" }).Count -ne 0) {
        throw "Block-only DB evidence fixture incorrectly produced MISSING_DB_MEMBER."
    }
    if (@($blockOnlyReport.findings | Where-Object { $_.code -eq "UNVERIFIED_DB_MEMBER" }).Count -eq 0) {
        throw "Block-only DB evidence fixture did not produce UNVERIFIED_DB_MEMBER."
    }

    $badTagPath = Join-Path $winccRoot "hmi-tag-import-map.csv"
    @"
"objectName","tag","layer","access","confirmation","note"
"BTN_启动_Start","状态数据_StateData.不存在_Missing","Cmd","write","mode-authority","broken binding"
"@ | Set-Content -LiteralPath $badTagPath -Encoding UTF8

    $missingJson = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $AnalyzerPath `
        -ProjectPath $projectRoot -ExportRoot $exportRoot -WinccPackagePath $winccRoot -OutputDirectory $missingOutput
    if ($LASTEXITCODE -ne 0) { throw "Missing-reference fixture process failed unexpectedly." }
    $missing = ($missingJson | Out-String).Trim() | ConvertFrom-Json
    if ($missing.contractStatus -ne "FAIL") {
        throw "Missing-reference fixture was not classified as FAIL."
    }
    $missingCount = @($missingJson | Out-Null)

    [pscustomobject]@{
        status = "passed"
        validStatus = $valid.contractStatus
        validDbMembers = $valid.counts.dbMembers
        validLadReferences = $valid.counts.ladReferences
        blockOnlyStatus = $blockOnly.contractStatus
        blockOnlyUnverified = $blockOnly.findingCounts.unverified
        missingStatus = $missing.contractStatus
        validReport = $valid.report
        missingReport = $missing.report
    } | ConvertTo-Json -Depth 6
}
finally {
    $resolvedTestRoot = [IO.Path]::GetFullPath($testRoot)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolvedTestRoot.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path -Leaf $resolvedTestRoot) -like "engineering-contract-test-*") {
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
