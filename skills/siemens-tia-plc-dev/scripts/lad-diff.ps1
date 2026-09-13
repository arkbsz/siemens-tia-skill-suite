param(
    [Parameter(Mandatory = $true)]
    [string]$BaseXml,

    [Parameter(Mandatory = $true)]
    [string]$CandidateXml,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [string]$JsonOutputPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Read-XmlDocument {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "LAD XML file was not found: $Path"
    }

    $document = New-Object System.Xml.XmlDocument
    $document.PreserveWhitespace = $true
    $document.XmlResolver = $null
    $document.Load((Resolve-Path -LiteralPath $Path).Path)
    return $document
}

function Get-NodeText {
    param([System.Xml.XmlNode]$Node)
    if ($null -eq $Node) {
        return ""
    }
    return ([string]$Node.InnerText).Trim()
}

function Get-ComponentPath {
    param([System.Xml.XmlNode]$Node)

    if ($null -eq $Node) {
        return ""
    }

    $names = @()
    foreach ($component in @($Node.SelectNodes(".//*[local-name()='Component']"))) {
        $name = $component.GetAttribute("Name")
        if (-not [string]::IsNullOrWhiteSpace($name)) {
            $names += $name
        }
    }
    return ($names -join ".")
}

function Get-AccessSummary {
    param([System.Xml.XmlNode]$Access)

    if ($null -eq $Access) {
        return ""
    }

    $scope = $Access.GetAttribute("Scope")
    $symbol = Get-ComponentPath $Access
    $constant = $Access.SelectSingleNode(".//*[local-name()='Constant']")
    if ($constant -and $constant.Attributes["Name"]) {
        $symbol = $constant.GetAttribute("Name")
    }
    if ([string]::IsNullOrWhiteSpace($symbol)) {
        $symbol = Get-NodeText ($Access.SelectSingleNode(".//*[local-name()='ConstantValue']"))
    }
    if ([string]::IsNullOrWhiteSpace($scope)) {
        return $symbol
    }
    if ([string]::IsNullOrWhiteSpace($symbol)) {
        return $scope
    }
    return ($scope + ":" + $symbol)
}

function Remove-VolatileAttributes {
    param([System.Xml.XmlNode]$Node)

    if ($null -eq $Node) {
        return
    }
    if ($Node -is [System.Xml.XmlElement] -and $Node.HasAttribute("UId")) {
        [void]$Node.RemoveAttribute("UId")
    }
    foreach ($child in @($Node.ChildNodes)) {
        Remove-VolatileAttributes $child
    }
}

function Get-Sha256 {
    param([Parameter(Mandatory = $true)][string]$Text)

    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return (([BitConverter]::ToString(
            $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))
        )) -replace "-", "").ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Get-NetworkRecords {
    param([Parameter(Mandatory = $true)][System.Xml.XmlDocument]$Document)

    $records = @()
    $units = @($Document.SelectNodes("//*[local-name()='SW.Blocks.CompileUnit']"))
    $index = 0
    foreach ($unit in $units) {
        $index++
        $attributeList = $unit.SelectSingleNode("./*[local-name()='AttributeList']")
        $networkSource = if ($attributeList) {
            $attributeList.SelectSingleNode("./*[local-name()='NetworkSource']")
        }
        else {
            $null
        }
        $flgNet = if ($networkSource) {
            $networkSource.SelectSingleNode("./*[local-name()='FlgNet']")
        }
        else {
            $null
        }

        $title = Get-NodeText ($unit.SelectSingleNode(".//*[local-name()='MultilingualText'][@CompositionName='Title']//*[local-name()='Text']"))
        $comment = Get-NodeText ($unit.SelectSingleNode(".//*[local-name()='MultilingualText'][@CompositionName='Comment']//*[local-name()='Text']"))
        $language = if ($attributeList) {
            Get-NodeText ($attributeList.SelectSingleNode("./*[local-name()='ProgrammingLanguage']"))
        }
        else {
            ""
        }
        $parts = @(
            if ($flgNet) {
                $flgNet.SelectNodes("./*[local-name()='Parts']/*")
            }
        )
        $wires = @(
            if ($flgNet) {
                $flgNet.SelectNodes("./*[local-name()='Wires']/*")
            }
        )

        $partSummaries = @()
        $instructionNames = @()
        $symbols = @()
        foreach ($part in $parts) {
            if ($part.LocalName -eq "Part") {
                $name = $part.GetAttribute("Name")
                if ([string]::IsNullOrWhiteSpace($name)) {
                    $name = "(unnamed)"
                }
                $version = $part.GetAttribute("Version")
                $display = if ([string]::IsNullOrWhiteSpace($version)) {
                    "Part:" + $name
                }
                else {
                    "Part:" + $name + "@" + $version
                }
                $partSummaries += $display
                $instructionNames += $name
            }
            elseif ($part.LocalName -eq "Access") {
                $symbols += (Get-AccessSummary $part)
            }
            else {
                $partSummaries += $part.LocalName
            }
        }

        $canonical = ""
        if ($flgNet) {
            $canonicalNode = $flgNet.CloneNode($true)
            Remove-VolatileAttributes $canonicalNode
            $canonical = [regex]::Replace(([string]$canonicalNode.OuterXml).Trim(), "\s+", " ")
        }
        $signatureText = @(
            $language
            $title
            $comment
            ($partSummaries -join "|")
            ($symbols -join "|")
            $canonical
        ) -join "`n"

        $records += [pscustomobject]@{
            Index = $index
            Title = $title
            Comment = $comment
            Language = $language
            PartCount = $parts.Count
            WireCount = $wires.Count
            Parts = $partSummaries
            Instructions = $instructionNames
            Symbols = $symbols
            Signature = Get-Sha256 $signatureText
        }
    }
    return $records
}

function Get-ArrayDifference {
    param(
        [string[]]$Left,
        [string[]]$Right
    )

    $leftSet = New-Object System.Collections.Generic.HashSet[string]([StringComparer]::OrdinalIgnoreCase)
    $rightSet = New-Object System.Collections.Generic.HashSet[string]([StringComparer]::OrdinalIgnoreCase)
    foreach ($value in @($Left)) {
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            [void]$leftSet.Add($value)
        }
    }
    foreach ($value in @($Right)) {
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            [void]$rightSet.Add($value)
        }
    }

    $added = @()
    $removed = @()
    foreach ($value in $rightSet) {
        if (-not $leftSet.Contains($value)) {
            $added += $value
        }
    }
    foreach ($value in $leftSet) {
        if (-not $rightSet.Contains($value)) {
            $removed += $value
        }
    }
    return [pscustomobject]@{
        Added = @($added | Sort-Object)
        Removed = @($removed | Sort-Object)
    }
}

function Get-NetworkChange {
    param(
        [int]$Index,
        [object]$Base,
        [object]$Candidate
    )

    if ($null -eq $Base) {
        return [pscustomobject]@{
            Index = $Index
            Change = "ADDED"
            Title = if ($Candidate) { $Candidate.Title } else { "" }
            Details = @("候选文件新增网络。")
            Base = $null
            Candidate = $Candidate
        }
    }
    if ($null -eq $Candidate) {
        return [pscustomobject]@{
            Index = $Index
            Change = "REMOVED"
            Title = $Base.Title
            Details = @("候选文件删除网络。")
            Base = $Base
            Candidate = $null
        }
    }
    if ($Base.Signature -eq $Candidate.Signature) {
        return [pscustomobject]@{
            Index = $Index
            Change = "UNCHANGED"
            Title = $Candidate.Title
            Details = @()
            Base = $Base
            Candidate = $Candidate
        }
    }

    $details = @()
    if ($Base.Title -ne $Candidate.Title) { $details += "标题发生变化。" }
    if ($Base.Comment -ne $Candidate.Comment) { $details += "注释发生变化。" }
    if ($Base.Language -ne $Candidate.Language) { $details += "编程语言发生变化。" }
    if ($Base.PartCount -ne $Candidate.PartCount) { $details += ("部件数量 " + $Base.PartCount + " -> " + $Candidate.PartCount + "。") }
    if ($Base.WireCount -ne $Candidate.WireCount) { $details += ("连线数量 " + $Base.WireCount + " -> " + $Candidate.WireCount + "。") }

    $instructionDiff = Get-ArrayDifference -Left $Base.Instructions -Right $Candidate.Instructions
    if ($instructionDiff.Added.Count -gt 0) {
        $details += ("新增指令：" + ($instructionDiff.Added -join ", ") + "。")
    }
    if ($instructionDiff.Removed.Count -gt 0) {
        $details += ("删除指令：" + ($instructionDiff.Removed -join ", ") + "。")
    }

    $symbolDiff = Get-ArrayDifference -Left $Base.Symbols -Right $Candidate.Symbols
    if ($symbolDiff.Added.Count -gt 0) {
        $details += ("新增符号：" + ($symbolDiff.Added -join ", ") + "。")
    }
    if ($symbolDiff.Removed.Count -gt 0) {
        $details += ("删除符号：" + ($symbolDiff.Removed -join ", ") + "。")
    }
    if ($details.Count -eq 0) {
        $details += "网络结构签名发生变化，请查看候选网络详情。"
    }

    return [pscustomobject]@{
        Index = $Index
        Change = "MODIFIED"
        Title = $Candidate.Title
        Details = $details
        Base = $Base
        Candidate = $Candidate
    }
}

function Escape-Md {
    param([object]$Value)
    $text = if ($null -eq $Value) { "" } else { [string]$Value }
    return ($text -replace "\|", "\|" -replace "`r?`n", " ")
}

$basePath = (Resolve-Path -LiteralPath $BaseXml).Path
$candidatePath = (Resolve-Path -LiteralPath $CandidateXml).Path
$baseDocument = Read-XmlDocument $basePath
$candidateDocument = Read-XmlDocument $candidatePath
$baseNetworks = @(Get-NetworkRecords $baseDocument)
$candidateNetworks = @(Get-NetworkRecords $candidateDocument)

$maxNetworkCount = [Math]::Max($baseNetworks.Count, $candidateNetworks.Count)
$changes = @()
for ($index = 1; $index -le $maxNetworkCount; $index++) {
    $base = $baseNetworks | Where-Object { $_.Index -eq $index } | Select-Object -First 1
    $candidate = $candidateNetworks | Where-Object { $_.Index -eq $index } | Select-Object -First 1
    $changes += (Get-NetworkChange -Index $index -Base $base -Candidate $candidate)
}

$changeArray = @($changes)
$summary = [ordered]@{
    Total = $changeArray.Count
    Added = @($changeArray | Where-Object { $_.Change -eq "ADDED" }).Count
    Removed = @($changeArray | Where-Object { $_.Change -eq "REMOVED" }).Count
    Modified = @($changeArray | Where-Object { $_.Change -eq "MODIFIED" }).Count
    Unchanged = @($changeArray | Where-Object { $_.Change -eq "UNCHANGED" }).Count
}

$result = [ordered]@{
    schemaVersion = 1
    kind = "siemens-lad-diff"
    generatedAt = (Get-Date).ToString("o")
    baseXml = $basePath
    candidateXml = $candidatePath
    baseSha256 = (Get-FileHash -LiteralPath $basePath -Algorithm SHA256).Hash.ToLowerInvariant()
    candidateSha256 = (Get-FileHash -LiteralPath $candidatePath -Algorithm SHA256).Hash.ToLowerInvariant()
    baseNetworkCount = $baseNetworks.Count
    candidateNetworkCount = $candidateNetworks.Count
    summary = $summary
    networks = $changeArray
}

$resolvedOutput = [IO.Path]::GetFullPath($OutputPath)
$resolvedJson = if ([string]::IsNullOrWhiteSpace($JsonOutputPath)) {
    [IO.Path]::ChangeExtension($resolvedOutput, ".json")
}
else {
    [IO.Path]::GetFullPath($JsonOutputPath)
}
New-Item -ItemType Directory -Path (Split-Path -Parent $resolvedOutput), (Split-Path -Parent $resolvedJson) -Force | Out-Null

$md = New-Object System.Text.StringBuilder
$codeTick = [char]96
[void]$md.AppendLine("# LAD结构差异审查")
[void]$md.AppendLine()
[void]$md.AppendLine("- 基准文件：" + $codeTick + $basePath + $codeTick)
[void]$md.AppendLine("- 候选文件：" + $codeTick + $candidatePath + $codeTick)
[void]$md.AppendLine("- 基准网络数：$($baseNetworks.Count)")
[void]$md.AppendLine("- 候选网络数：$($candidateNetworks.Count)")
[void]$md.AppendLine("- 变更统计：新增 $($summary.Added)，删除 $($summary.Removed)，修改 $($summary.Modified)，未变化 $($summary.Unchanged)")
[void]$md.AppendLine()
[void]$md.AppendLine("比较规则：按网络顺序比较；结构签名会移除 TIA 导出中易变化的 `UId`，同时保留标题、注释、编程语言、部件、符号和连线结构。")
[void]$md.AppendLine()
[void]$md.AppendLine("## 网络汇总")
[void]$md.AppendLine()
[void]$md.AppendLine("| 网络 | 状态 | 标题 | 指令 | 部件 | 连线 |")
[void]$md.AppendLine("| --- | --- | --- | --- | ---: | ---: |")
foreach ($change in $changeArray) {
    $network = if ($change.Candidate) { $change.Candidate } else { $change.Base }
    $instructions = if ($network) { @($network.Instructions) -join ", " } else { "" }
    [void]$md.AppendLine("| " + $change.Index + " | " + $change.Change + " | " + (Escape-Md $change.Title) + " | " + (Escape-Md $instructions) + " | " + $network.PartCount + " | " + $network.WireCount + " |")
}
[void]$md.AppendLine()
[void]$md.AppendLine("## 变更详情")
[void]$md.AppendLine()
foreach ($change in ($changeArray | Where-Object { $_.Change -ne "UNCHANGED" })) {
    [void]$md.AppendLine("### 网络 " + $change.Index + "：" + $change.Change + " " + (Escape-Md $change.Title))
    foreach ($detail in @($change.Details)) {
        [void]$md.AppendLine("- " + $detail)
    }
    if ($change.Candidate) {
        [void]$md.AppendLine("- 候选符号：" + $codeTick + (Escape-Md ((@($change.Candidate.Symbols) -join ", "))) + $codeTick)
        [void]$md.AppendLine("- 候选结构：" + $codeTick + (Escape-Md ((@($change.Candidate.Parts) -join ", "))) + $codeTick)
    }
    [void]$md.AppendLine()
}
if ($summary.Added -eq 0 -and $summary.Removed -eq 0 -and $summary.Modified -eq 0) {
    [void]$md.AppendLine("未检测到网络结构变化。")
}

[IO.File]::WriteAllText($resolvedOutput, $md.ToString(), (New-Object System.Text.UTF8Encoding($false)))
[IO.File]::WriteAllText($resolvedJson, ($result | ConvertTo-Json -Depth 20), (New-Object System.Text.UTF8Encoding($false)))

[pscustomobject]@{
    Status = "Passed"
    BaseXml = $basePath
    CandidateXml = $candidatePath
    OutputPath = $resolvedOutput
    JsonOutputPath = $resolvedJson
    TotalNetworks = $summary.Total
    Added = $summary.Added
    Removed = $summary.Removed
    Modified = $summary.Modified
    Unchanged = $summary.Unchanged
} | ConvertTo-Json -Depth 6
