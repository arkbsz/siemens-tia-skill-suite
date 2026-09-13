param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    [string]$WorkflowConfigPath = "",
    [string]$ContractReportPath = "",
    [string]$WinccPackagePath = "",
    [string]$OutputDirectory = "",
    [string]$ApplyReviewPath = "",
    [switch]$ApplyToPackage
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

function Ensure-Directory {
    param([string]$Path)
    if (-not [string]::IsNullOrWhiteSpace($Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Get-FirstExistingPath {
    param([string[]]$Paths)
    foreach ($path in $Paths) {
        if (-not [string]::IsNullOrWhiteSpace($path) -and (Test-Path -LiteralPath $path)) {
            return (Get-Item -LiteralPath $path).FullName
        }
    }
    return ""
}

function Get-OptionalPropertyValue {
    param(
        [object]$Object,
        [string[]]$Names,
        [string]$Fallback = ""
    )
    if ($null -eq $Object) { return $Fallback }
    foreach ($name in $Names) {
        $property = $Object.PSObject.Properties[$name]
        if ($property -and -not [string]::IsNullOrWhiteSpace([string]$property.Value)) {
            return ([string]$property.Value).Trim()
        }
    }
    return $Fallback
}

function Import-CsvSafe {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return @()
    }
    return @(Import-Csv -LiteralPath $Path -Encoding UTF8)
}

function Write-Utf8Bom {
    param([string]$Path, [string]$Content)
    $encoding = New-Object System.Text.UTF8Encoding($true)
    [IO.File]::WriteAllText($Path, $Content, $encoding)
}

function Write-JsonFile {
    param([string]$Path, [object]$Object)
    $Object | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Get-TextProperty {
    param([object]$Object, [string[]]$Names)
    return Get-OptionalPropertyValue -Object $Object -Names $Names
}

function Get-NameTerms {
    param([string]$Text)
    $value = if ($null -eq $Text) { "" } else { [string]$Text }
    $terms = New-Object System.Collections.Generic.List[string]
    if ([string]::IsNullOrWhiteSpace($value)) { return @() }

    $dictionary = [ordered]@{
        "start" = @("启动", "开始")
        "stop" = @("停止", "停机")
        "run" = @("运行", "运行中")
        "running" = @("运行", "运行中")
        "feedback" = @("反馈", "状态")
        "status" = @("状态", "状态")
        "interlock" = @("互锁", "允许", "就绪")
        "reason" = @("原因", "诊断")
        "alarm" = @("报警", "故障")
        "fault" = @("故障", "报警")
        "active" = @("激活", "当前")
        "speed" = @("速度", "频率")
        "setpoint" = @("设定", "给定")
        "sp" = @("设定", "给定")
        "comm" = @("通信", "通讯")
        "communication" = @("通信", "通讯")
        "timeout" = @("超时", "超时")
        "overload" = @("过载", "故障")
        "current" = @("当前", "实际")
        "step" = @("步骤", "步")
        "reset" = @("复位", "重置")
        "ack" = @("确认", "应答")
        "auto" = @("自动", "自动")
        "manual" = @("手动", "手动")
        "home" = @("原点", "回零")
        "position" = @("位置", "位置")
        "velocity" = @("速度", "速度")
    }
    foreach ($part in ($value -split "[^A-Za-z0-9\p{IsCJKUnifiedIdeographs}]+")) {
        if ([string]::IsNullOrWhiteSpace($part)) { continue }
        $lower = $part.ToLowerInvariant()
        [void]$terms.Add($lower)
        if ($dictionary.Contains($lower)) {
            foreach ($mapped in $dictionary[$lower]) { [void]$terms.Add($mapped) }
        }
    }
    foreach ($pair in $dictionary.GetEnumerator()) {
        if ($value.ToLowerInvariant().Contains($pair.Key) -or
            @($pair.Value | Where-Object { $value.Contains([string]$_) }).Count -gt 0) {
            foreach ($mapped in $pair.Value) { [void]$terms.Add($mapped) }
        }
    }
    return @($terms.ToArray() | Select-Object -Unique)
}

function Get-ReferenceText {
    param([object]$Row, [string]$ObjectType)
    if ($ObjectType -eq "ALARM") {
        return @(
            (Get-TextProperty -Object $Row -Names @("alarmName")),
            (Get-TextProperty -Object $Row -Names @("triggerTag")),
            (Get-TextProperty -Object $Row -Names @("class"))
        ) -join " "
    }
    return @(
        (Get-TextProperty -Object $Row -Names @("objectName")),
        (Get-TextProperty -Object $Row -Names @("tag")),
        (Get-TextProperty -Object $Row -Names @("layer")),
        (Get-TextProperty -Object $Row -Names @("access"))
    ) -join " "
}

function Get-LayerTerms {
    param([object]$Row, [string]$ObjectType)
    $text = Get-ReferenceText -Row $Row -ObjectType $ObjectType
    $terms = New-Object System.Collections.Generic.List[string]
    foreach ($term in (Get-NameTerms -Text $text)) { [void]$terms.Add($term) }
    if ($ObjectType -eq "ALARM" -or
        (Get-TextProperty -Object $Row -Names @("layer")) -match "^(Alm|Alarm)$") {
        foreach ($term in @("报警", "故障", "alarm")) { [void]$terms.Add($term) }
    }
    return @($terms.ToArray() | Select-Object -Unique)
}

function Get-CandidateScore {
    param(
        [object]$Candidate,
        [object]$Row,
        [string]$ObjectType
    )
    $reference = (Get-ReferenceText -Row $Row -ObjectType $ObjectType).Trim()
    $isAlarmLike = $ObjectType -eq "ALARM" -or
        (Get-TextProperty -Object $Row -Names @("layer")) -match "^(Alm|Alarm)$"
    $candidateText = @(
        [string]$Candidate.path,
        [string]$Candidate.name,
        [string]$Candidate.dbName
    ) -join " "
    $score = 0
    $reasons = New-Object System.Collections.Generic.List[string]
    $referenceTerms = @(Get-LayerTerms -Row $Row -ObjectType $ObjectType)
    $candidateTerms = @(Get-NameTerms -Text $candidateText)
    foreach ($term in $referenceTerms) {
        if ($candidateTerms -contains $term) {
            $score += 14
            [void]$reasons.Add("语义词:$term")
        }
    }
    $tag = Get-TextProperty -Object $Row -Names @("tag", "triggerTag")
    if (-not [string]::IsNullOrWhiteSpace($tag) -and
        ([string]$Candidate.name -eq $tag -or [string]$Candidate.path -eq $tag)) {
        $score += 100
        [void]$reasons.Add("名称完全匹配")
    }
    $tagChinese = ($tag -replace "_[A-Za-z][A-Za-z0-9_]*$", "")
    if (-not [string]::IsNullOrWhiteSpace($tagChinese) -and
        ([string]$Candidate.name).Contains($tagChinese)) {
        $score += 35
        [void]$reasons.Add("中文语义前缀匹配")
    }
    if (-not [string]::IsNullOrWhiteSpace($tagChinese) -and
        $tagChinese.Contains([string]$Candidate.name)) {
        $score += 30
        [void]$reasons.Add("中文信号名包含候选")
    }
    $access = (Get-TextProperty -Object $Row -Names @("access")).ToLowerInvariant()
    if ($access -eq "write") {
        if ([bool]$Candidate.writable) {
            $score += 10
            [void]$reasons.Add("目标可写")
        }
        else {
            $score -= 35
            [void]$reasons.Add("目标不可确认可写")
        }
    }
    if ($isAlarmLike -and
        ([string]$Candidate.name -match "报警|故障|超时|过载|通信")) {
        $score += 18
        [void]$reasons.Add("报警候选优先")
    }
    if ($isAlarmLike -and
        -not [string]::IsNullOrWhiteSpace([string]$Candidate.datatype) -and
        [string]$Candidate.datatype -notmatch "^(Bool|Boolean)$") {
        $score -= 20
        [void]$reasons.Add("报警触发通常需要Bool")
    }
    if ($reference -match "反馈|运行|Run|Fb" -and
        ([string]$Candidate.name -match "实际|Actual|状态|运行|反馈|Running")) {
        $score += 12
        [void]$reasons.Add("反馈状态候选")
    }
    if ($reference -match "反馈|运行|Run|Fb" -and
        ([string]$Candidate.name -match "通信|通讯|Comm|Communication")) {
        $score -= 18
        [void]$reasons.Add("通信状态不等于设备运行反馈")
    }
    if ($reference -match "设定|给定|速度|Speed|Setpoint|Sp" -and
        ([string]$Candidate.name -match "设定|给定|点动|定位|速度|Speed|Setpoint|Sp")) {
        $score += 12
        [void]$reasons.Add("设定值候选")
    }
    if ($reference -match "速度|频率|Speed|Velocity" -and
        ([string]$Candidate.name -match "速度|频率|Speed|Velocity")) {
        $score += 18
        [void]$reasons.Add("速度/频率类型匹配")
    }
    if ($reference -match "速度|频率|Speed|Velocity" -and
        ([string]$Candidate.name -match "位置|Position")) {
        $score -= 18
        [void]$reasons.Add("位置值不应作为速度设定")
    }
    if ($reference -match "设定|给定|Speed|Setpoint|Sp" -and
        ([string]$Candidate.name -match "实际|当前|Actual")) {
        $score -= 20
        [void]$reasons.Add("实际反馈不应作为设定")
    }
    if ($reference -match "命令|Cmd|启动|停止|复位|Start|Stop|Reset" -and
        ([string]$Candidate.name -match "Counter|Timer|FirstScan|Denied|CV|状态|反馈|Actual")) {
        $score -= 25
        [void]$reasons.Add("系统/状态对象不适合作为命令")
    }
    if ([string]$Candidate.datatype -match "String|WString" -and
        $reference -match "报警|原因|Reason") {
        $score += 8
        [void]$reasons.Add("文本诊断类型")
    }
    return [pscustomobject]@{
        score = $score
        reason = (@($reasons.ToArray() | Select-Object -Unique) -join "；")
    }
}

function Get-Confidence {
    param([int]$Score, [int]$Gap, [int]$CandidateCount)
    if ($Score -ge 70 -and $Gap -ge 20 -and $CandidateCount -gt 0) { return "HIGH_REVIEW_REQUIRED" }
    if ($Score -ge 35 -and $Gap -ge 10 -and $CandidateCount -gt 0) { return "MEDIUM_REVIEW_REQUIRED" }
    return "LOW_REVIEW_REQUIRED"
}

function Get-ReviewValue {
    param([object]$Row, [string[]]$Names)
    return Get-OptionalPropertyValue -Object $Row -Names $Names
}

function Add-Or-SetProperty {
    param([object]$Object, [string]$Name, [object]$Value)
    $property = $Object.PSObject.Properties[$Name]
    if ($property) {
        $property.Value = $Value
    }
    else {
        $Object | Add-Member -MemberType NoteProperty -Name $Name -Value $Value
    }
}

function Test-SafePackagePath {
    param([string]$Root, [string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd("\") + "\"
    $pathFull = [IO.Path]::GetFullPath($Path)
    return $pathFull.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)
}

$root = Resolve-ProjectDirectory -Path $ProjectPath
$workspaceRoot = Join-Path $root "PLC_Code"
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $workspaceRoot "wincc\binding-review\latest"
}
Ensure-Directory -Path $OutputDirectory

if ([string]::IsNullOrWhiteSpace($ContractReportPath)) {
    $ContractReportPath = Join-Path $workspaceRoot "engineering-contracts\latest\engineering-contract-report.json"
}
if (-not (Test-Path -LiteralPath $ContractReportPath -PathType Leaf)) {
    $analyzer = Join-Path $PSScriptRoot "analyze-engineering-contracts.ps1"
    $analyzerOutput = Join-Path $workspaceRoot "engineering-contracts\latest"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $analyzer `
        -ProjectPath $root -OutputDirectory $analyzerOutput
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $ContractReportPath -PathType Leaf)) {
        throw "工程契约报告不存在，且自动分析失败：$ContractReportPath"
    }
}
$contractReport = Get-Content -LiteralPath $ContractReportPath -Raw -Encoding UTF8 | ConvertFrom-Json

if ([string]::IsNullOrWhiteSpace($WinccPackagePath)) {
    $WinccPackagePath = Get-FirstExistingPath -Paths @(
        (Join-Path $workspaceRoot "wincc\engineering-scaffold\latest"),
        (Join-Path $workspaceRoot "wincc\openness-implementation\latest"),
        (Join-Path $workspaceRoot "wincc\design-workflow\latest"),
        (Join-Path $workspaceRoot "wincc\tasks\latest")
    )
}
if ([string]::IsNullOrWhiteSpace($WinccPackagePath)) {
    throw "没有找到 WinCC 工程包，请先生成 WinCC 脚手架或提供 -WinccPackagePath。"
}
$tagPath = Get-FirstExistingPath -Paths @(
    (Join-Path $WinccPackagePath "hmi-tag-import-map.csv"),
    (Join-Path $workspaceRoot "wincc\engineering-scaffold\latest\hmi-tag-import-map.csv"),
    (Join-Path $workspaceRoot "wincc\openness-implementation\latest\hmi-tag-import-map.csv")
)
$alarmPath = Get-FirstExistingPath -Paths @(
    (Join-Path $WinccPackagePath "alarm-import-map.csv"),
    (Join-Path $workspaceRoot "wincc\engineering-scaffold\latest\alarm-import-map.csv"),
    (Join-Path $workspaceRoot "wincc\openness-implementation\latest\alarm-import-map.csv")
)
$hmiTags = Import-CsvSafe -Path $tagPath
$alarms = Import-CsvSafe -Path $alarmPath

$candidates = New-Object System.Collections.Generic.List[object]
foreach ($member in @($contractReport.dbMembers)) {
    $dbName = [string]$member.dbName
    $memberPath = [string]$member.memberPath
    if ([string]::IsNullOrWhiteSpace($dbName) -or [string]::IsNullOrWhiteSpace($memberPath)) { continue }
    [void]$candidates.Add([pscustomobject]@{
        path = "$dbName.$memberPath"
        name = $memberPath
        dbName = $dbName
        matchType = "DB_MEMBER"
        datatype = [string]$member.datatype
        writable = [bool]$member.writable
        source = [string]$member.sourceXml
    })
}
foreach ($group in @($contractReport.ladReferences |
    Where-Object { $_.referenceType -eq "GLOBAL_SYMBOL" -and -not [string]::IsNullOrWhiteSpace($_.symbolPath) } |
    Group-Object symbolPath)) {
    $symbol = [string]$group.Name
    [void]$candidates.Add([pscustomobject]@{
        path = $symbol
        name = $symbol
        dbName = ""
        matchType = "LAD_GLOBAL_SYMBOL"
        datatype = ""
        writable = $true
        source = [string]$group.Group[0].sourceXml
    })
}
    $candidates = @($candidates.ToArray() |
        Where-Object {
            [string]$_.path -notmatch "^(IEC_|MB_|MC_|FirstScan)" -and
            [string]$_.path -notmatch "\.CV$"
        } |
        Sort-Object path,matchType -Unique)

$reviewRows = New-Object System.Collections.Generic.List[object]
$candidateRows = New-Object System.Collections.Generic.List[object]
function Add-BindingRows {
    param(
        [object[]]$Rows,
        [string]$ObjectType,
        [string]$SourcePath
    )
    foreach ($row in @($Rows)) {
        $objectName = Get-TextProperty -Object $row -Names @("objectName", "alarmName")
        $tag = Get-TextProperty -Object $row -Names @("tag", "triggerTag")
        $currentBinding = Get-TextProperty -Object $row -Names @("plcPath", "plcTag", "binding", "plcVariable", "address", "sourceTag")
        $ranked = @(
            foreach ($candidate in $candidates) {
                $score = Get-CandidateScore -Candidate $candidate -Row $row -ObjectType $ObjectType
                [pscustomobject]@{
                    candidate = $candidate
                    score = [int]$score.score
                    reason = [string]$score.reason
                }
            }
        ) | Sort-Object -Property @{ Expression = "score"; Descending = $true }, path
        $top = @($ranked | Where-Object { [int]$_.score -gt 0 } | Select-Object -First 5)
        $bestScore = if ($top.Count -gt 0) { [int]$top[0].score } else { 0 }
        $secondScore = if ($top.Count -gt 1) { [int]$top[1].score } else { 0 }
        $gap = $bestScore - $secondScore
        $confidence = Get-Confidence -Score $bestScore -Gap $gap -CandidateCount $top.Count
        $recommended = if ($top.Count -gt 0 -and $confidence -ne "LOW_REVIEW_REQUIRED") {
            [string]$top[0].candidate.path
        }
        else {
            ""
        }
        $recommendedReason = if ($top.Count -gt 0) { [string]$top[0].reason } else { "没有可用候选。" }
        $candidateText = @(
            foreach ($entry in $top) {
                "{0} [{1}, {2}]" -f [string]$entry.candidate.path,[int]$entry.score,[string]$entry.candidate.matchType
            }
        ) -join "; "
        $review = [pscustomobject]@{
            objectType = $ObjectType
            objectName = $objectName
            tag = $tag
            triggerTag = if ($ObjectType -eq "ALARM") { $tag } else { "" }
            currentBinding = $currentBinding
            recommendedBinding = $recommended
            confidence = $confidence
            score = $bestScore
            scoreGap = $gap
            candidateCount = $top.Count
            candidatePaths = $candidateText
            decision = if ($currentBinding) { "existing-binding-review" } else { "pending" }
            selectedBinding = if ($currentBinding) { $currentBinding } else { "" }
            reviewNote = ""
            source = $SourcePath
        }
        [void]$reviewRows.Add($review)
        $rank = 0
        foreach ($entry in $top) {
            $rank++
            [void]$candidateRows.Add([pscustomobject]@{
                objectType = $ObjectType
                objectName = $objectName
                tag = $tag
                candidateRank = $rank
                candidateBinding = [string]$entry.candidate.path
                matchType = [string]$entry.candidate.matchType
                datatype = [string]$entry.candidate.datatype
                writable = [bool]$entry.candidate.writable
                score = [int]$entry.score
                confidence = $confidence
                reason = [string]$entry.reason
                source = [string]$entry.candidate.source
            })
        }
    }
}
Add-BindingRows -Rows $hmiTags -ObjectType "HMI_TAG" -SourcePath $tagPath
Add-BindingRows -Rows $alarms -ObjectType "ALARM" -SourcePath $alarmPath

$candidateCsv = Join-Path $OutputDirectory "binding-candidates.csv"
$reviewCsv = Join-Path $OutputDirectory "binding-review.csv"
$reviewMd = Join-Path $OutputDirectory "binding-review.md"
$providedReviewRows = @()
if ($ApplyReviewPath -and (Test-Path -LiteralPath $ApplyReviewPath -PathType Leaf)) {
    # Read the engineer's approval before refreshing the generated review files.
    $providedReviewRows = @(Import-Csv -LiteralPath $ApplyReviewPath -Encoding UTF8)
}
@($candidateRows.ToArray()) | Export-Csv -LiteralPath $candidateCsv -NoTypeInformation -Encoding UTF8
@($reviewRows.ToArray()) | Export-Csv -LiteralPath $reviewCsv -NoTypeInformation -Encoding UTF8

$md = New-Object System.Text.StringBuilder
[void]$md.AppendLine("# WinCC PLC 绑定审核包")
[void]$md.AppendLine()
[void]$md.AppendLine("- 工程: ``$root``")
[void]$md.AppendLine("- WinCC 包: ``$WinccPackagePath``")
[void]$md.AppendLine("- 当前绑定只读分析，不自动写入生产工程。")
[void]$md.AppendLine("- 审核方法: 修改 ``binding-review.csv`` 的 ``selectedBinding`` 和 ``decision``；批准值使用 ``approve`` 或 ``approved``。")
[void]$md.AppendLine()
[void]$md.AppendLine("| 类型 | 对象 | 当前绑定 | 推荐绑定 | 置信级别 | 分数 | 候选 |")
[void]$md.AppendLine("| --- | --- | --- | --- | --- | ---: | --- |")
foreach ($row in @($reviewRows.ToArray())) {
    [void]$md.AppendLine("| $($row.objectType) | $($row.objectName) | $($row.currentBinding) | $($row.recommendedBinding) | $($row.confidence) | $($row.score) | $($row.candidatePaths) |")
}
Write-Utf8Bom -Path $reviewMd -Content $md.ToString()

$application = $null
if ($ApplyReviewPath) {
    if (-not (Test-Path -LiteralPath $ApplyReviewPath -PathType Leaf)) {
        throw "审核文件不存在：$ApplyReviewPath"
    }
    $reviewInputRows = if ($providedReviewRows.Count -gt 0) {
        $providedReviewRows
    }
    else {
        @(Import-Csv -LiteralPath $ApplyReviewPath -Encoding UTF8)
    }
    $approved = @($reviewInputRows |
        Where-Object {
            [string]$_.decision -match "^(approve|approved|confirmed|确认|批准)$" -and
            -not [string]::IsNullOrWhiteSpace([string]$_.selectedBinding)
        })
    if ($approved.Count -eq 0) {
        throw "审核文件没有可应用的批准行。"
    }
    $reviewPackageRoot = Join-Path $OutputDirectory "applied"
    Ensure-Directory -Path $reviewPackageRoot
    $tagOutput = Join-Path $reviewPackageRoot "hmi-tag-import-map.csv"
    $alarmOutput = Join-Path $reviewPackageRoot "alarm-import-map.csv"
    $tagOutputRows = @($hmiTags | ForEach-Object {
        $item = $_
        $match = @($approved | Where-Object {
            [string]$_.objectType -eq "HMI_TAG" -and [string]$_.objectName -eq [string]$item.objectName
        } | Select-Object -First 1)
        if ($match.Count -gt 0) { Add-Or-SetProperty -Object $item -Name "plcPath" -Value ([string]$match[0].selectedBinding) }
        $item
    })
    $alarmOutputRows = @($alarms | ForEach-Object {
        $item = $_
        $match = @($approved | Where-Object {
            [string]$_.objectType -eq "ALARM" -and [string]$_.objectName -eq [string]$item.alarmName
        } | Select-Object -First 1)
        if ($match.Count -gt 0) { Add-Or-SetProperty -Object $item -Name "plcPath" -Value ([string]$match[0].selectedBinding) }
        $item
    })
    @($tagOutputRows) | Export-Csv -LiteralPath $tagOutput -NoTypeInformation -Encoding UTF8
    @($alarmOutputRows) | Export-Csv -LiteralPath $alarmOutput -NoTypeInformation -Encoding UTF8

    if ($ApplyToPackage) {
        if (-not (Test-SafePackagePath -Root $root -Path $WinccPackagePath)) {
            throw "拒绝写入工程目录之外的 WinCC 包：$WinccPackagePath"
        }
        $backupDir = Join-Path $workspaceRoot ("file-backups\wincc-binding-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
        Ensure-Directory -Path $backupDir
        if ($tagPath) { Copy-Item -LiteralPath $tagPath -Destination (Join-Path $backupDir (Split-Path -Leaf $tagPath)) -Force }
        if ($alarmPath) { Copy-Item -LiteralPath $alarmPath -Destination (Join-Path $backupDir (Split-Path -Leaf $alarmPath)) -Force }
        if ($tagPath) { Copy-Item -LiteralPath $tagOutput -Destination $tagPath -Force }
        if ($alarmPath) { Copy-Item -LiteralPath $alarmOutput -Destination $alarmPath -Force }
    }
    $application = [pscustomobject]@{
        status = "applied"
        approvedCount = $approved.Count
        derivedTagMap = $tagOutput
        derivedAlarmMap = $alarmOutput
        appliedToPackage = [bool]$ApplyToPackage
        backupDirectory = if ($ApplyToPackage) { $backupDir } else { "" }
    }
}

$result = [pscustomobject]@{
    status = "ok"
    projectRoot = $root
    contractReportPath = (Get-Item -LiteralPath $ContractReportPath).FullName
    winccPackagePath = $WinccPackagePath
    outputDirectory = (Get-Item -LiteralPath $OutputDirectory).FullName
    hmiTagCount = $hmiTags.Count
    alarmCount = $alarms.Count
    plcCandidateCount = $candidates.Count
    reviewCount = $reviewRows.Count
    candidateCsv = $candidateCsv
    reviewCsv = $reviewCsv
    reviewMarkdown = $reviewMd
    application = $application
}
Write-JsonFile -Path (Join-Path $OutputDirectory "binding-assistant.json") -Object $result
$result | ConvertTo-Json -Depth 12
