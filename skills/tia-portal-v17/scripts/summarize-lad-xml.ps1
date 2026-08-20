param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [string]$OutputPath,

    [ValidateSet("Markdown", "Json")]
    [string]$Format = "Markdown"
)

$ErrorActionPreference = "Stop"

function Select-LocalNodes {
    param([System.Xml.XmlNode]$Node, [string]$LocalName)
    return @($Node.SelectNodes(".//*[local-name()='$LocalName']"))
}

function Select-CompileUnits {
    param([System.Xml.XmlNode]$Node)
    return @($Node.SelectNodes(".//*[local-name()='CompileUnit' or local-name()='SW.Blocks.CompileUnit']"))
}

function Get-Attr {
    param([System.Xml.XmlNode]$Node, [string]$Name)
    if ($Node.Attributes -and $Node.Attributes[$Name]) { return $Node.Attributes[$Name].Value }
    return $null
}

function Get-TextByComposition {
    param([System.Xml.XmlNode]$Node, [string]$CompositionName)
    $textNode = $Node.SelectSingleNode("./*[local-name()='ObjectList']/*[local-name()='MultilingualText' and @CompositionName='$CompositionName']//*[local-name()='Text']")
    if ($textNode) { return $textNode.InnerText }
    return ""
}

function Get-SymbolText {
    param([System.Xml.XmlNode]$Node)
    $symbolNode = $Node.SelectSingleNode("./*[local-name()='Symbol']")
    if ($symbolNode) {
        $parts = @($symbolNode.SelectNodes(".//*[local-name()='Component']") | ForEach-Object { Get-Attr -Node $_ -Name "Name" } | Where-Object { $_ })
        if ($parts.Count -gt 0) { return ($parts -join ".") }
    }

    $constantNode = $Node.SelectSingleNode("./*[local-name()='Constant']")
    if ($constantNode) {
        $valueNode = $constantNode.SelectSingleNode("./*[local-name()='ConstantValue']")
        if ($valueNode) { return $valueNode.InnerText }
    }

    return $null
}

function Get-BlockName {
    param([xml]$Xml)
    $blockNode = @($Xml.DocumentElement.ChildNodes | Where-Object { $_.LocalName -like "SW.Blocks.*" } | Select-Object -First 1)[0]
    if (-not $blockNode) { return [System.IO.Path]::GetFileNameWithoutExtension($Xml.BaseURI) }
    $nameNode = $blockNode.SelectSingleNode("./*[local-name()='AttributeList']/*[local-name()='Name']")
    if ($nameNode) { return $nameNode.InnerText }
    return $blockNode.LocalName
}

function Get-AccessMap {
    param([System.Xml.XmlNode]$Unit)
    $map = @{}
    $nodes = @($Unit.SelectNodes(".//*[local-name()='Access' or local-name()='Instance']"))
    foreach ($node in $nodes) {
        $uid = Get-Attr -Node $node -Name "UId"
        $symbol = Get-SymbolText -Node $node
        if ($uid -and $symbol) { $map[$uid] = $symbol }
    }
    return $map
}

function Get-PartMap {
    param([System.Xml.XmlNode]$Unit)
    $map = @{}
    foreach ($part in Select-LocalNodes -Node $Unit -LocalName "Part") {
        $uid = Get-Attr -Node $part -Name "UId"
        if ($uid) { $map[$uid] = $part }
    }
    return $map
}

function Get-TemplateValue {
    param([System.Xml.XmlNode]$Part, [string]$Name)
    $node = $Part.SelectSingleNode("./*[local-name()='TemplateValue' and @Name='$Name']")
    if ($node) { return $node.InnerText }
    return $null
}

function Get-SignalInputMap {
    param([System.Xml.XmlNode]$Unit)

    $map = @{}
    foreach ($wire in Select-LocalNodes -Node $Unit -LocalName "Wire") {
        $nameCons = @($wire.SelectNodes("./*[local-name()='NameCon']") | ForEach-Object {
            [pscustomobject]@{
                UId = Get-Attr -Node $_ -Name "UId"
                Name = Get-Attr -Node $_ -Name "Name"
            }
        })
        if ($nameCons.Count -eq 0) { continue }

        $hasPowerrail = $wire.SelectSingleNode("./*[local-name()='Powerrail']") -ne $null
        $identCon = $wire.SelectSingleNode("./*[local-name()='IdentCon']")
        if ($identCon) { continue }

        if ($hasPowerrail) {
            foreach ($target in $nameCons) {
                if (-not $target.UId -or -not $target.Name) { continue }
                $map["{0}|{1}" -f $target.UId, $target.Name] = [pscustomobject]@{
                    Kind = "Powerrail"
                }
            }
            continue
        }

        if ($nameCons.Count -lt 2) { continue }

        $source = @($nameCons | Where-Object { $_.Name -in @("out", "Q", "ENO") } | Select-Object -First 1)[0]
        if (-not $source) { continue }

        foreach ($target in @($nameCons | Where-Object { -not ($_.UId -eq $source.UId -and $_.Name -eq $source.Name) })) {
            if (-not $target.UId -or -not $target.Name) { continue }
            $map["{0}|{1}" -f $target.UId, $target.Name] = [pscustomobject]@{
                Kind = "Part"
                FromPartUid = $source.UId
                FromName = $source.Name
            }
        }
    }

    return $map
}

function Get-SignalSource {
    param(
        [hashtable]$SignalInputMap,
        [string]$PartUid,
        [string]$InputName
    )

    $key = "{0}|{1}" -f $PartUid, $InputName
    if ($SignalInputMap.ContainsKey($key)) {
        return $SignalInputMap[$key]
    }

    return $null
}

function Get-PartConnections {
    param(
        [System.Xml.XmlNode]$Unit,
        [System.Xml.XmlNode]$Part,
        [hashtable]$AccessMap
    )

    $partUid = Get-Attr -Node $Part -Name "UId"
    $connections = @{}
    if (-not $partUid) { return $connections }

    foreach ($wire in Select-LocalNodes -Node $Unit -LocalName "Wire") {
        $ident = $wire.SelectSingleNode("./*[local-name()='IdentCon']")
        if (-not $ident) { continue }
        $identUid = Get-Attr -Node $ident -Name "UId"
        if (-not $AccessMap.ContainsKey($identUid)) { continue }
        foreach ($nameCon in @($wire.SelectNodes("./*[local-name()='NameCon']"))) {
            if ((Get-Attr -Node $nameCon -Name "UId") -ne $partUid) { continue }
            $name = Get-Attr -Node $nameCon -Name "Name"
            if (-not $name) { $name = "value" }
            if (-not $connections.ContainsKey($name)) { $connections[$name] = New-Object System.Collections.Generic.List[string] }
            $connections[$name].Add($AccessMap[$identUid])
        }
    }

    foreach ($instance in @($Part.SelectNodes("./*[local-name()='Instance']"))) {
        $uid = Get-Attr -Node $instance -Name "UId"
        if ($uid -and $AccessMap.ContainsKey($uid)) {
            if (-not $connections.ContainsKey("instance")) { $connections["instance"] = New-Object System.Collections.Generic.List[string] }
            $connections["instance"].Add($AccessMap[$uid])
        }
    }

    return $connections
}

function Format-Connections {
    param([hashtable]$Connections)
    $items = @()
    foreach ($key in @($Connections.Keys | Sort-Object)) {
        $items += ("{0}={1}" -f $key, (@($Connections[$key]) -join "|"))
    }
    return ($items -join ", ")
}

function Get-PartSignalExpression {
    param(
        [string]$PartUid,
        [System.Xml.XmlNode]$Unit,
        [hashtable]$PartMap,
        [hashtable]$SignalInputMap,
        [hashtable]$AccessMap,
        [hashtable]$Cache
    )

    if (-not $PartUid) { return "" }
    if ($Cache.ContainsKey($PartUid)) { return $Cache[$PartUid] }
    if (-not $PartMap.ContainsKey($PartUid)) { return "" }

    $part = $PartMap[$PartUid]
    $name = Get-Attr -Node $part -Name "Name"
    $expression = ""

    switch -Regex ($name) {
        "^O$" {
            $branches = New-Object System.Collections.Generic.List[string]
            $cardText = Get-TemplateValue -Part $part -Name "Card"
            $branchCount = 0
            if ($cardText) {
                [void][int]::TryParse($cardText, [ref]$branchCount)
            }

            if ($branchCount -le 0) {
                $branchCount = @($SignalInputMap.Keys | Where-Object { $_ -like "$PartUid|in*" }).Count
            }

            for ($index = 1; $index -le $branchCount; $index++) {
                $source = Get-SignalSource -SignalInputMap $SignalInputMap -PartUid $PartUid -InputName ("in{0}" -f $index)
                if (-not $source -or $source.Kind -ne "Part") { continue }
                $branchExpression = Get-PartSignalExpression -PartUid ([string]$source.FromPartUid) -Unit $Unit -PartMap $PartMap -SignalInputMap $SignalInputMap -AccessMap $AccessMap -Cache $Cache
                if ($branchExpression) {
                    $branches.Add($branchExpression)
                }
            }

            if ($branches.Count -gt 0) {
                $expression = "(" + (@($branches.ToArray()) -join ") OR (") + ")"
            }
        }
        "^Contact$" {
            $selfExpression = Describe-Part -Part $part -Connections (Get-PartConnections -Unit $Unit -Part $part -AccessMap $AccessMap)
            $source = Get-SignalSource -SignalInputMap $SignalInputMap -PartUid $PartUid -InputName "in"

            if (-not $source -or $source.Kind -eq "Powerrail") {
                $expression = $selfExpression
            }
            elseif ($source.Kind -eq "Part") {
                $upstreamExpression = Get-PartSignalExpression -PartUid ([string]$source.FromPartUid) -Unit $Unit -PartMap $PartMap -SignalInputMap $SignalInputMap -AccessMap $AccessMap -Cache $Cache
                if ($upstreamExpression) {
                    $expression = "($upstreamExpression) AND $selfExpression"
                }
                else {
                    $expression = $selfExpression
                }
            }
        }
        "^(PContact|NContact|Eq|Ne|Ge|Gt|Le|Lt)$" {
            $selfExpression = Describe-Part -Part $part -Connections (Get-PartConnections -Unit $Unit -Part $part -AccessMap $AccessMap)
            $source = Get-SignalSource -SignalInputMap $SignalInputMap -PartUid $PartUid -InputName "pre"

            if (-not $source -or $source.Kind -eq "Powerrail") {
                $expression = $selfExpression
            }
            elseif ($source.Kind -eq "Part") {
                $upstreamExpression = Get-PartSignalExpression -PartUid ([string]$source.FromPartUid) -Unit $Unit -PartMap $PartMap -SignalInputMap $SignalInputMap -AccessMap $AccessMap -Cache $Cache
                if ($upstreamExpression) {
                    $expression = "($upstreamExpression) AND $selfExpression"
                }
                else {
                    $expression = $selfExpression
                }
            }
        }
        "^TON$" {
            $source = Get-SignalSource -SignalInputMap $SignalInputMap -PartUid $PartUid -InputName "IN"
            if ($source -and $source.Kind -eq "Part") {
                $expression = Get-PartSignalExpression -PartUid ([string]$source.FromPartUid) -Unit $Unit -PartMap $PartMap -SignalInputMap $SignalInputMap -AccessMap $AccessMap -Cache $Cache
            }
        }
    }

    $Cache[$PartUid] = $expression
    return $expression
}

function Describe-Part {
    param(
        [System.Xml.XmlNode]$Part,
        [hashtable]$Connections
    )

    $name = Get-Attr -Node $Part -Name "Name"
    $operand = if ($Connections.ContainsKey("operand")) { @($Connections["operand"])[0] } else { "" }
    $isNegated = $Part.SelectSingleNode("./*[local-name()='Negated' and @Name='operand']") -ne $null
    $params = Format-Connections -Connections $Connections

    switch -Regex ($name) {
        "^Contact$" { if ($isNegated) { return "NC($operand)" } else { return "NO($operand)" } }
        "^PContact$" { return "P_EDGE($operand)" }
        "^NContact$" { return "N_EDGE($operand)" }
        "^Coil$" { return "COIL($operand)" }
        "^SCoil$" { return "SET($operand)" }
        "^RCoil$" { return "RESET($operand)" }
        "^(Eq|Ne|Ge|Gt|Le|Lt)$" { return "$name($params)" }
        default {
            if ($params) { return "$name($params)" }
            return $name
        }
    }
}

function Get-NetworkConditionSummary {
    param(
        [System.Xml.XmlNode]$Unit,
        [System.Xml.XmlNode[]]$Parts,
        [hashtable]$AccessMap
    )

    $partMap = Get-PartMap -Unit $Unit
    $signalInputMap = Get-SignalInputMap -Unit $Unit
    $cache = @{}

    $actionParts = @($Parts | Where-Object {
        (Get-Attr -Node $_ -Name "Name") -match "^(Coil|SCoil|RCoil|Move|TON|TOF|TP|CTU|CTD|CTUD|MC_|MB_)$"
    })

    foreach ($actionPart in $actionParts) {
        $actionPartUid = Get-Attr -Node $actionPart -Name "UId"
        $actionName = Get-Attr -Node $actionPart -Name "Name"
        switch ($actionName) {
            "TON" {
                $source = Get-SignalSource -SignalInputMap $signalInputMap -PartUid $actionPartUid -InputName "IN"
                if (-not $source -or $source.Kind -ne "Part") { continue }

                $expression = Get-PartSignalExpression -PartUid ([string]$source.FromPartUid) -Unit $Unit -PartMap $partMap -SignalInputMap $signalInputMap -AccessMap $AccessMap -Cache $cache
                if ($expression) { return $expression }
            }
            "CTU" {
                $summaryParts = New-Object System.Collections.Generic.List[string]

                $cuSource = Get-SignalSource -SignalInputMap $signalInputMap -PartUid $actionPartUid -InputName "CU"
                if ($cuSource -and $cuSource.Kind -eq "Part") {
                    $cuExpression = Get-PartSignalExpression -PartUid ([string]$cuSource.FromPartUid) -Unit $Unit -PartMap $partMap -SignalInputMap $signalInputMap -AccessMap $AccessMap -Cache $cache
                    if ($cuExpression) { $summaryParts.Add("CU=($cuExpression)") }
                }

                $rSource = Get-SignalSource -SignalInputMap $signalInputMap -PartUid $actionPartUid -InputName "R"
                if ($rSource -and $rSource.Kind -eq "Part") {
                    $rExpression = Get-PartSignalExpression -PartUid ([string]$rSource.FromPartUid) -Unit $Unit -PartMap $partMap -SignalInputMap $signalInputMap -AccessMap $AccessMap -Cache $cache
                    if ($rExpression) { $summaryParts.Add("R=($rExpression)") }
                }

                if ($summaryParts.Count -gt 0) {
                    return ($summaryParts -join "; ")
                }
            }
            default {
                $source = Get-SignalSource -SignalInputMap $signalInputMap -PartUid $actionPartUid -InputName "in"
                if (-not $source -or $source.Kind -ne "Part") { continue }

                $expression = Get-PartSignalExpression -PartUid ([string]$source.FromPartUid) -Unit $Unit -PartMap $partMap -SignalInputMap $signalInputMap -AccessMap $AccessMap -Cache $cache
                if ($expression) { return $expression }
            }
        }
    }

    foreach ($orPart in @($Parts | Where-Object { (Get-Attr -Node $_ -Name "Name") -eq "O" })) {
        $expression = Get-PartSignalExpression -PartUid (Get-Attr -Node $orPart -Name "UId") -Unit $Unit -PartMap $partMap -SignalInputMap $signalInputMap -AccessMap $AccessMap -Cache $cache
        if ($expression) { return $expression }
    }

    return ""
}

function Get-ActionBranchSummaries {
    param(
        [System.Xml.XmlNode]$Unit,
        [System.Xml.XmlNode[]]$Parts,
        [hashtable]$AccessMap
    )

    $partMap = Get-PartMap -Unit $Unit
    $signalInputMap = Get-SignalInputMap -Unit $Unit
    $cache = @{}
    $branchGroups = New-Object System.Collections.Generic.List[object]

    $actionParts = @($Parts | Where-Object {
        (Get-Attr -Node $_ -Name "Name") -match "^(Coil|SCoil|RCoil|Move|TON|TOF|TP|MC_|MB_)$"
    })

    foreach ($actionPart in $actionParts) {
        $actionPartUid = Get-Attr -Node $actionPart -Name "UId"
        if (-not $actionPartUid) { continue }

        $actionName = Get-Attr -Node $actionPart -Name "Name"
        $actionText = Describe-Part -Part $actionPart -Connections (Get-PartConnections -Unit $Unit -Part $actionPart -AccessMap $AccessMap)
        $inputExpressions = New-Object System.Collections.Generic.List[string]

        foreach ($signalKey in @($signalInputMap.Keys | Where-Object { $_ -like "$actionPartUid|*" } | Sort-Object)) {
            $inputName = ($signalKey -split "\|", 2)[1]
            $source = $signalInputMap[$signalKey]
            if (-not $source -or $source.Kind -ne "Part") { continue }
            if ($inputName -eq "en" -and $actionName -notin @("Move")) { continue }

            $expression = Get-PartSignalExpression -PartUid ([string]$source.FromPartUid) -Unit $Unit -PartMap $partMap -SignalInputMap $signalInputMap -AccessMap $AccessMap -Cache $cache
            if (-not $expression) { continue }
            if (-not @($inputExpressions.ToArray()) -contains $expression) {
                $inputExpressions.Add($expression)
            }
        }

        if ($inputExpressions.Count -ne 1) { continue }
        $conditionText = [string]$inputExpressions[0]

        $existingGroup = @($branchGroups | Where-Object { $_.Condition -eq $conditionText } | Select-Object -First 1)[0]
        if (-not $existingGroup) {
            $existingGroup = [pscustomobject]@{
                Condition = $conditionText
                Actions = (New-Object System.Collections.Generic.List[string])
            }
            $branchGroups.Add($existingGroup)
        }

        $existingGroup.Actions.Add($actionText)
    }

    if ($branchGroups.Count -le 1) {
        return @()
    }

    return @($branchGroups.ToArray() | ForEach-Object {
        [pscustomobject]@{
            Condition = $_.Condition
            Actions = @($_.Actions.ToArray())
        }
    })
}

function Convert-File {
    param([System.IO.FileInfo]$File)

    $xml = New-Object System.Xml.XmlDocument
    $xml.PreserveWhitespace = $true
    $xml.Load($File.FullName)
    $blockName = Get-BlockName -Xml $xml
    $languageNode = $xml.SelectSingleNode("//*[local-name()='ProgrammingLanguage']")
    $language = if ($languageNode) { $languageNode.InnerText } else { "" }
    $units = Select-CompileUnits -Node $xml

    $networks = @()
    $index = 0
    foreach ($unit in $units) {
        $index++
        $accessMap = Get-AccessMap -Unit $unit
        $parts = @(Select-LocalNodes -Node $unit -LocalName "Part")
        $conditions = New-Object System.Collections.Generic.List[string]
        $actions = New-Object System.Collections.Generic.List[string]
        $elements = New-Object System.Collections.Generic.List[string]

        foreach ($part in $parts) {
            $name = Get-Attr -Node $part -Name "Name"
            $desc = Describe-Part -Part $part -Connections (Get-PartConnections -Unit $unit -Part $part -AccessMap $accessMap)
            if ($name -match "^(Contact|PContact|NContact|Eq|Ne|Ge|Gt|Le|Lt|O)$") {
                $conditions.Add($desc)
            }
            elseif ($name -match "^(Coil|SCoil|RCoil|Move|TON|TOF|TP|CTU|CTD|CTUD|MC_|MB_)") {
                $actions.Add($desc)
            }
            else {
                $elements.Add($desc)
            }
        }

        $conditionSummary = Get-NetworkConditionSummary -Unit $unit -Parts $parts -AccessMap $accessMap
        $conditionOutput = if ($conditionSummary) { @($conditionSummary) } else { @($conditions) }
        $branchSummaries = @(Get-ActionBranchSummaries -Unit $unit -Parts $parts -AccessMap $accessMap)

        $networks += [pscustomobject]@{
            Index = $index
            ID = Get-Attr -Node $unit -Name "ID"
            Title = Get-TextByComposition -Node $unit -CompositionName "Title"
            Comment = Get-TextByComposition -Node $unit -CompositionName "Comment"
            Conditions = $conditionOutput
            Actions = @($actions)
            Branches = $branchSummaries
            Elements = @($elements)
            Symbols = @($accessMap.Values | Sort-Object -Unique)
        }
    }

    return [pscustomobject]@{
        File = $File.FullName
        Block = $blockName
        Language = $language
        NetworkCount = $networks.Count
        Networks = $networks
    }
}

$item = Get-Item -LiteralPath $Path
$files = if ($item.PSIsContainer) {
    @(Get-ChildItem -LiteralPath $item.FullName -Recurse -File | Where-Object { $_.Extension -ieq ".xml" })
} else {
    @($item)
}

$result = @($files | ForEach-Object { Convert-File -File $_ })

if ($Format -eq "Json") {
    $content = $result | ConvertTo-Json -Depth 10
}
else {
    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($block in $result) {
        $lines.Add("# $($block.Block)")
        $lines.Add("")
        $lines.Add(("- File: ``{0}``" -f $block.File))
        $lines.Add(("- Language: ``{0}``" -f $block.Language))
        $lines.Add(("- Networks: ``{0}``" -f $block.NetworkCount))
        $lines.Add("")
        foreach ($network in $block.Networks) {
            $title = if ($network.Title) { $network.Title } else { "(untitled)" }
            $lines.Add("## Network $($network.Index): $title")
            if ($network.Comment) { $lines.Add("Comment: $($network.Comment)") }
            if (@($network.Branches).Count -gt 0) {
                foreach ($branch in $network.Branches) {
                    $lines.Add("BRANCH IF " + $branch.Condition + " THEN " + (@($branch.Actions) -join "; "))
                }
            }
            else {
                if ($network.Conditions.Count -gt 0) { $lines.Add("IF " + (@($network.Conditions) -join " AND ")) }
                if ($network.Actions.Count -gt 0) { $lines.Add("THEN " + (@($network.Actions) -join "; ")) }
            }
            if ($network.Elements.Count -gt 0) { $lines.Add("ELEMENTS " + (@($network.Elements) -join "; ")) }
            if ($network.Symbols.Count -gt 0) { $lines.Add("SYMBOLS " + (@($network.Symbols) -join ", ")) }
            $lines.Add("")
        }
    }
    $content = $lines -join [Environment]::NewLine
}

if ($OutputPath) {
    $outDir = Split-Path -Parent $OutputPath
    if ($outDir) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
    Set-Content -LiteralPath $OutputPath -Value $content -Encoding UTF8
    [pscustomobject]@{ OutputPath = (Get-Item -LiteralPath $OutputPath).FullName; Files = $files.Count } | ConvertTo-Json -Depth 3
}
else {
    $content
}
