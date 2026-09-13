param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    [string]$WorkflowConfigPath = "",
    [string]$OutputDirectory = "",
    [string]$ExportRoot = "",
    [string]$WinccPackagePath = ""
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

function Get-Text {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return ""
    }
    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8
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

function Get-LatestBlockList {
    param([string]$WorkspaceRoot)
    $runsRoot = Join-Path $WorkspaceRoot "runs"
    if (-not (Test-Path -LiteralPath $runsRoot -PathType Container)) { return "" }
    $files = Get-ChildItem -LiteralPath $runsRoot -Recurse -File -Filter "block-list.txt" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending
    if ($files) { return $files[0].FullName }
    return ""
}

function Parse-BlockList {
    param([string]$Path)
    $blocks = New-Object System.Collections.Generic.List[object]
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return @()
    }
    foreach ($line in (Get-Content -LiteralPath $Path -Encoding UTF8)) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line.StartsWith("#") -or $line.StartsWith("Name`t") -or
            $line.StartsWith("STARTING`t") -or $line.StartsWith("OPENING`t") -or
            $line.StartsWith("OPENED`t")) { continue }
        $parts = $line -split "`t"
        if ($parts.Count -lt 4) { continue }
        [void]$blocks.Add([pscustomobject]@{
            name = [string]$parts[0]
            type = [string]$parts[1]
            number = [string]$parts[2]
            language = [string]$parts[3]
            group = if ($parts.Count -gt 4) { [string]$parts[4] } else { "" }
            consistent = if ($parts.Count -gt 5) { [string]$parts[5] } else { "" }
            source = $Path
        })
    }
    return @($blocks.ToArray())
}

function Get-XmlDocument {
    param([string]$Path)
    try {
        $document = New-Object System.Xml.XmlDocument
        $document.PreserveWhitespace = $true
        $document.Load($Path)
        return $document
    }
    catch {
        return $null
    }
}

function Get-NodeText {
    param([System.Xml.XmlNode]$Node)
    if ($null -eq $Node) { return "" }
    return [string]$Node.InnerText
}

function Get-AttributeValue {
    param([System.Xml.XmlNode]$Node, [string]$Name)
    if ($null -eq $Node -or $null -eq $Node.Attributes) { return "" }
    $attribute = $Node.Attributes[$Name]
    if ($attribute) { return [string]$attribute.Value }
    return ""
}

function Get-BlockNode {
    param([System.Xml.XmlDocument]$Document)
    if ($null -eq $Document) { return $null }
    return $Document.SelectSingleNode("//*[contains(local-name(), 'SW.Blocks.')][1]")
}

function Get-BlockName {
    param([System.Xml.XmlNode]$BlockNode)
    $nameNode = $BlockNode.SelectSingleNode("./*[local-name()='AttributeList']/*[local-name()='Name']")
    if ($nameNode) { return [string]$nameNode.InnerText }
    return ""
}

function Get-BlockType {
    param([System.Xml.XmlNode]$BlockNode)
    if ($null -eq $BlockNode) { return "" }
    $localName = [string]$BlockNode.LocalName
    $index = $localName.LastIndexOf(".")
    if ($index -ge 0) { return $localName.Substring($index + 1) }
    return $localName
}

function Get-BlockNumber {
    param([System.Xml.XmlNode]$BlockNode)
    $numberNode = $BlockNode.SelectSingleNode("./*[local-name()='AttributeList']/*[local-name()='Number']")
    if ($numberNode) { return [string]$numberNode.InnerText }
    return ""
}

function Get-ProgrammingLanguage {
    param([System.Xml.XmlNode]$BlockNode)
    $languageNode = $BlockNode.SelectSingleNode("./*[local-name()='AttributeList']/*[local-name()='ProgrammingLanguage']")
    if ($languageNode) { return [string]$languageNode.InnerText }
    return ""
}

function Get-UniqueXmlFiles {
    param([string]$Root)
    if ([string]::IsNullOrWhiteSpace($Root) -or -not (Test-Path -LiteralPath $Root -PathType Container)) {
        return @()
    }

    $files = Get-ChildItem -LiteralPath $Root -Recurse -File -Filter "*.xml" -ErrorAction SilentlyContinue
    $byIdentity = @{}
    foreach ($file in $files) {
        $document = Get-XmlDocument -Path $file.FullName
        $blockNode = Get-BlockNode -Document $document
        if ($null -eq $blockNode) { continue }
        $name = Get-BlockName -BlockNode $blockNode
        if ([string]::IsNullOrWhiteSpace($name)) { continue }
        $identity = (Get-BlockType -BlockNode $blockNode) + "|" + $name + "|" + (Get-BlockNumber -BlockNode $blockNode)
        if (-not $byIdentity.ContainsKey($identity) -or
            $file.LastWriteTime -gt $byIdentity[$identity].file.LastWriteTime) {
            $byIdentity[$identity] = [pscustomobject]@{
                file = $file
                document = $document
                blockNode = $blockNode
            }
        }
    }
    return @($byIdentity.Values | Sort-Object { $_.file.FullName })
}

function Add-DbMemberRecursive {
    param(
        [System.Xml.XmlNode]$MemberNode,
        [string]$DbName,
        [string]$Section,
        [string]$ParentPath,
        [string]$SourceXml,
        [System.Collections.Generic.List[object]]$Members
    )

    $name = Get-AttributeValue -Node $MemberNode -Name "Name"
    if ([string]::IsNullOrWhiteSpace($name)) { return }
    $memberPath = if ([string]::IsNullOrWhiteSpace($ParentPath)) { $name } else { $ParentPath + "." + $name }
    $datatype = Get-AttributeValue -Node $MemberNode -Name "Datatype"
    $accessibility = Get-AttributeValue -Node $MemberNode -Name "Accessibility"
    $startNode = $MemberNode.SelectSingleNode("./*[local-name()='StartValue']")
    $externalWritable = $MemberNode.SelectSingleNode(".//*[local-name()='BooleanAttribute' and @Name='ExternalWritable']")
    $externalVisible = $MemberNode.SelectSingleNode(".//*[local-name()='BooleanAttribute' and @Name='ExternalVisible']")
    $writable = ([string]$externalWritable.InnerText -eq "true") -or
        (-not [string]::Equals($accessibility, "ReadOnly", [StringComparison]::OrdinalIgnoreCase))

    [void]$Members.Add([pscustomobject]@{
        dbName = $DbName
        section = $Section
        memberName = $name
        memberPath = $memberPath
        datatype = $datatype
        accessibility = $accessibility
        writable = $writable
        externallyVisible = ([string]$externalVisible.InnerText -eq "true")
        startValue = if ($startNode) { [string]$startNode.InnerText } else { "" }
        sourceXml = $SourceXml
    })

    foreach ($child in $MemberNode.SelectNodes("./*[local-name()='Member']")) {
        Add-DbMemberRecursive -MemberNode $child -DbName $DbName -Section $Section `
            -ParentPath $memberPath -SourceXml $SourceXml -Members $Members
    }
}

function Get-DbMembers {
    param([object[]]$XmlEntries)
    $members = New-Object System.Collections.Generic.List[object]
    foreach ($entry in $XmlEntries) {
        $blockNode = $entry.blockNode
        if ((Get-BlockType -BlockNode $blockNode) -ne "GlobalDB") { continue }
        $dbName = Get-BlockName -BlockNode $blockNode
        $sections = $blockNode.SelectNodes(".//*[local-name()='Interface']/*[local-name()='Sections']/*[local-name()='Section']")
        foreach ($sectionNode in $sections) {
            $section = Get-AttributeValue -Node $sectionNode -Name "Name"
            foreach ($memberNode in $sectionNode.SelectNodes("./*[local-name()='Member']")) {
                Add-DbMemberRecursive -MemberNode $memberNode -DbName $dbName -Section $section `
                    -ParentPath "" -SourceXml $entry.file.FullName -Members $members
            }
        }
    }
    return @($members.ToArray())
}

function Get-DbEvidence {
    param(
        [object[]]$Blocks,
        [object[]]$XmlEntries,
        [object[]]$DbMembers
    )
    $names = New-Object System.Collections.Generic.List[string]
    foreach ($name in @($Blocks | Where-Object { $_.type -eq "GlobalDB" } | Select-Object -ExpandProperty name)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$name)) { [void]$names.Add([string]$name) }
    }
    foreach ($entry in $XmlEntries) {
        if ((Get-BlockType -BlockNode $entry.blockNode) -eq "GlobalDB") {
            $name = Get-BlockName -BlockNode $entry.blockNode
            if (-not [string]::IsNullOrWhiteSpace($name)) { [void]$names.Add($name) }
        }
    }

    $evidence = New-Object System.Collections.Generic.List[object]
    foreach ($name in @($names.ToArray() | Select-Object -Unique | Sort-Object)) {
        $blockMatches = @($Blocks | Where-Object { $_.type -eq "GlobalDB" -and $_.name -eq $name })
        $xmlMatches = @($XmlEntries | Where-Object {
            (Get-BlockType -BlockNode $_.blockNode) -eq "GlobalDB" -and
            (Get-BlockName -BlockNode $_.blockNode) -eq $name
        })
        $memberMatches = @($DbMembers | Where-Object { $_.dbName -eq $name })
        $status = if ($memberMatches.Count -gt 0) {
            "VERIFIED_MEMBERS"
        }
        elseif ($xmlMatches.Count -gt 0) {
            "XML_WITHOUT_MEMBERS"
        }
        elseif ($blockMatches.Count -gt 0) {
            "BLOCK_ONLY"
        }
        else {
            "UNSEEN"
        }
        $confidence = if ($status -eq "VERIFIED_MEMBERS") {
            "VERIFIED"
        }
        elseif ($status -eq "BLOCK_ONLY" -or $status -eq "XML_WITHOUT_MEMBERS") {
            "PARTIAL"
        }
        else {
            "UNKNOWN"
        }
        [void]$evidence.Add([pscustomobject]@{
            name = $name
            blockDeclared = ($blockMatches.Count -gt 0)
            xmlExported = ($xmlMatches.Count -gt 0)
            memberEvidenceCount = $memberMatches.Count
            status = $status
            confidence = $confidence
            blockListSource = if ($blockMatches.Count -gt 0) { [string]$blockMatches[0].source } else { "" }
            xmlSources = (@($xmlMatches | ForEach-Object { $_.file.FullName }) -join ";")
        })
    }
    return @($evidence.ToArray())
}

function Get-InstanceEvidence {
    param(
        [string]$InstancePath,
        [object[]]$Blocks,
        [object[]]$XmlEntries,
        [string]$SourceXml
    )
    if ([string]::IsNullOrWhiteSpace($InstancePath)) {
        return [pscustomobject]@{
            exists = $true
            evidenceStatus = "NOT_APPLICABLE"
            confidence = "VERIFIED"
            originClass = "NONE"
            evidenceSource = ""
        }
    }

    $blockMatch = @($Blocks | Where-Object { $_.name -eq $InstancePath })
    if ($blockMatch.Count -gt 0) {
        return [pscustomobject]@{
            exists = $true
            evidenceStatus = "VERIFIED_BLOCK"
            confidence = "VERIFIED"
            originClass = "PROJECT_BLOCK"
            evidenceSource = [string]$blockMatch[0].source
        }
    }

    $xmlMatch = @($XmlEntries | Where-Object {
        (Get-BlockName -BlockNode $_.blockNode) -eq $InstancePath
    })
    if ($xmlMatch.Count -gt 0) {
        return [pscustomobject]@{
            exists = $true
            evidenceStatus = "VERIFIED_XML"
            confidence = "VERIFIED"
            originClass = "EXPORTED_BLOCK"
            evidenceSource = [string]$xmlMatch[0].file.FullName
        }
    }

    $sourceDirectory = if (-not [string]::IsNullOrWhiteSpace($SourceXml)) {
        Split-Path -Parent $SourceXml
    }
    else {
        ""
    }
    $supportingDirectory = if ($sourceDirectory) {
        Join-Path $sourceDirectory "supporting-sources"
    }
    else {
        ""
    }
    if ($supportingDirectory -and (Test-Path -LiteralPath $supportingDirectory -PathType Container)) {
        $supportingMatch = Get-ChildItem -LiteralPath $supportingDirectory -File -ErrorAction SilentlyContinue |
            Where-Object { $_.BaseName -eq $InstancePath } |
            Select-Object -First 1
        if ($supportingMatch) {
            return [pscustomobject]@{
                exists = $true
                evidenceStatus = "VERIFIED_SUPPORTING_SOURCE"
                confidence = "PARTIAL"
                originClass = "SUPPORTING_SOURCE"
                evidenceSource = $supportingMatch.FullName
            }
        }
    }

    $originClass = if ($InstancePath -match "^(IEC_|MC_|MB_|PID_|TO_|Technology_)") {
        "SYSTEM_OR_LIBRARY"
    }
    else {
        "USER_OR_UNKNOWN"
    }
    return [pscustomobject]@{
        exists = $false
        evidenceStatus = "UNVERIFIED_INSTANCE"
        confidence = "UNKNOWN"
        originClass = $originClass
        evidenceSource = ""
    }
}

function Get-ComponentsPath {
    param([System.Xml.XmlNode]$Node)
    $components = @($Node.SelectNodes(".//*[local-name()='Component']") | ForEach-Object {
        Get-AttributeValue -Node $_ -Name "Name"
    } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    return ($components -join ".")
}

function Get-LadReferences {
    param(
        [object[]]$XmlEntries,
        [object[]]$DbMembers,
        [object[]]$Blocks,
        [object[]]$DbEvidence
    )
    $references = New-Object System.Collections.Generic.List[object]
    $dbNames = @($DbEvidence | Select-Object -ExpandProperty name -Unique)
    $dbNames = @($dbNames | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)

    foreach ($entry in $XmlEntries) {
        $language = Get-ProgrammingLanguage -BlockNode $entry.blockNode
        if ($language -notin @("LAD", "FBD")) { continue }
        $compileUnits = @($entry.blockNode.SelectNodes(".//*[contains(local-name(), 'CompileUnit')]"))
        $networkIndex = 0
        foreach ($unit in $compileUnits) {
            $networkIndex++
            $flgNets = @($unit.SelectNodes(".//*[local-name()='FlgNet']"))
            foreach ($flgNet in $flgNets) {
                foreach ($access in @($flgNet.SelectNodes("./*[local-name()='Parts']/*[local-name()='Access']"))) {
                    $path = Get-ComponentsPath -Node $access
                    if ([string]::IsNullOrWhiteSpace($path)) { continue }
                    $components = $path -split "\."
                    $rootName = $components[0]
                    $memberPath = if ($components.Count -gt 1) { ($components[1..($components.Count - 1)] -join ".") } else { "" }
                    $referenceType = if ($dbNames -contains $rootName) { "DB_MEMBER" } else { "GLOBAL_SYMBOL" }
                    $exists = $false
                    $evidenceStatus = "NOT_APPLICABLE"
                    $evidenceSource = ""
                    $dbBlockDeclared = $false
                    $dbXmlExported = $false
                    $dbMemberEvidenceCount = 0
                    if ($referenceType -eq "DB_MEMBER") {
                        $dbEvidenceMatch = @($DbEvidence | Where-Object { $_.name -eq $rootName } | Select-Object -First 1)
                        if ($dbEvidenceMatch.Count -gt 0) {
                            $dbEvidenceMatch = $dbEvidenceMatch[0]
                            $dbBlockDeclared = [bool]$dbEvidenceMatch.blockDeclared
                            $dbXmlExported = [bool]$dbEvidenceMatch.xmlExported
                            $dbMemberEvidenceCount = [int]$dbEvidenceMatch.memberEvidenceCount
                            $evidenceSource = if (-not [string]::IsNullOrWhiteSpace([string]$dbEvidenceMatch.xmlSources)) {
                                [string]$dbEvidenceMatch.xmlSources
                            }
                            else {
                                [string]$dbEvidenceMatch.blockListSource
                            }
                        }
                        if ([string]::IsNullOrWhiteSpace($memberPath)) {
                            $exists = $true
                            $evidenceStatus = "VERIFIED_DB_BLOCK"
                        }
                        else {
                            $exists = @($DbMembers | Where-Object {
                                $_.dbName -eq $rootName -and $_.memberPath -eq $memberPath
                            }).Count -gt 0
                            $evidenceStatus = if ($exists) {
                                "VERIFIED_MEMBER"
                            }
                            elseif ($dbMemberEvidenceCount -gt 0) {
                                "MISSING_MEMBER"
                            }
                            elseif ($dbXmlExported) {
                                "XML_WITHOUT_MEMBER_EVIDENCE"
                            }
                            elseif ($dbBlockDeclared) {
                                "BLOCK_ONLY"
                            }
                            else {
                                "NO_DB_EVIDENCE"
                            }
                        }
                    }
                    [void]$references.Add([pscustomobject]@{
                        blockName = Get-BlockName -BlockNode $entry.blockNode
                        network = $networkIndex
                        scope = Get-AttributeValue -Node $access -Name "Scope"
                        symbolPath = $path
                        rootName = $rootName
                        memberPath = $memberPath
                        referenceType = $referenceType
                        exists = $exists
                        evidenceStatus = $evidenceStatus
                        evidenceSource = $evidenceSource
                        dbBlockDeclared = $dbBlockDeclared
                        dbXmlExported = $dbXmlExported
                        dbMemberEvidenceCount = $dbMemberEvidenceCount
                        sourceXml = $entry.file.FullName
                    })
                }

                foreach ($part in @($flgNet.SelectNodes("./*[local-name()='Parts']/*[local-name()='Part']"))) {
                    $instruction = Get-AttributeValue -Node $part -Name "Name"
                    if ([string]::IsNullOrWhiteSpace($instruction)) { continue }
                    $instance = $part.SelectSingleNode("./*[local-name()='Instance']")
                    $instancePath = if ($instance) { Get-ComponentsPath -Node $instance } else { "" }
                    $instanceEvidence = Get-InstanceEvidence -InstancePath $instancePath `
                        -Blocks $Blocks -XmlEntries $XmlEntries -SourceXml $entry.file.FullName
                    [void]$references.Add([pscustomobject]@{
                        blockName = Get-BlockName -BlockNode $entry.blockNode
                        network = $networkIndex
                        scope = "Instruction"
                        symbolPath = if ($instancePath) { $instruction + " -> " + $instancePath } else { $instruction }
                        rootName = $instruction
                        memberPath = $instancePath
                        referenceType = "INSTRUCTION"
                        exists = $instanceEvidence.exists
                        evidenceStatus = $instanceEvidence.evidenceStatus
                        confidence = $instanceEvidence.confidence
                        originClass = $instanceEvidence.originClass
                        evidenceSource = $instanceEvidence.evidenceSource
                        instruction = $instruction
                        instance = $instancePath
                        sourceXml = $entry.file.FullName
                    })
                }
            }
        }
    }
    return @($references.ToArray())
}

function Import-CsvSafe {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return @()
    }
    try {
        return @(Import-Csv -LiteralPath $Path -Encoding UTF8)
    }
    catch {
        return @()
    }
}

function Get-OptionalPropertyValue {
    param(
        [object]$Object,
        [string[]]$Names
    )
    if ($null -eq $Object) { return "" }
    foreach ($name in $Names) {
        $property = $Object.PSObject.Properties[$name]
        if ($property -and -not [string]::IsNullOrWhiteSpace([string]$property.Value)) {
            return ([string]$property.Value).Trim()
        }
    }
    return ""
}

function Import-TagContractBindings {
    param([string]$Path)
    $rows = New-Object System.Collections.Generic.List[object]
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return @()
    }
    $headers = @()
    foreach ($line in (Get-Content -LiteralPath $Path -Encoding UTF8)) {
        if (-not $line.Trim().StartsWith("|")) { continue }
        $cells = @($line.Trim().Trim("|").Split("|") | ForEach-Object { ([string]$_).Trim() })
        if ($cells.Count -lt 2) { continue }
        if ($cells -join "|" -match "^-+\|") { continue }
        if ($headers.Count -eq 0) {
            $headers = $cells
            continue
        }
        $tagIndex = -1
        $bindingIndex = -1
        for ($i = 0; $i -lt $headers.Count; $i++) {
            if ($headers[$i] -match "^(Tag|标签)$") { $tagIndex = $i }
            if ($headers[$i] -match "(PLC|Binding|Path|变量|绑定)") { $bindingIndex = $i }
        }
        if ($tagIndex -lt 0 -or $bindingIndex -lt 0 -or
            $tagIndex -ge $cells.Count -or $bindingIndex -ge $cells.Count) { continue }
        $tag = $cells[$tagIndex]
        $binding = $cells[$bindingIndex]
        if ([string]::IsNullOrWhiteSpace($tag) -or [string]::IsNullOrWhiteSpace($binding)) { continue }
        [void]$rows.Add([pscustomobject]@{
            tag = $tag
            binding = $binding
            source = $Path
        })
    }
    return @($rows.ToArray())
}

function Get-TagBinding {
    param(
        [object]$TagObject,
        [object[]]$ContractBindings
    )
    # "source" describes the design artifact and is not a PLC address.
    $binding = Get-OptionalPropertyValue -Object $TagObject -Names @(
        "plcPath", "plcTag", "binding", "plcVariable", "address", "sourceTag"
    )
    if ($binding) {
        return [pscustomobject]@{
            value = $binding
            source = "CSV"
        }
    }
    $tag = Get-OptionalPropertyValue -Object $TagObject -Names @("tag", "triggerTag")
    $contractMatch = @($ContractBindings | Where-Object { $_.tag -eq $tag } | Select-Object -First 1)
    if ($contractMatch.Count -gt 0) {
        return [pscustomobject]@{
            value = [string]$contractMatch[0].binding
            source = [string]$contractMatch[0].source
        }
    }
    return [pscustomobject]@{
        value = ""
        source = ""
    }
}

function Find-WinccFile {
    param([string]$Root, [string]$Name)
    if ([string]::IsNullOrWhiteSpace($Root)) { return "" }
    $candidate = Join-Path $Root $Name
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { return (Get-Item -LiteralPath $candidate).FullName }
    return ""
}

function Get-ContractTargetCandidates {
    param([string]$Tag)
    $value = if ($null -eq $Tag) { "" } else { ([string]$Tag).Trim() }
    $candidates = New-Object System.Collections.Generic.List[string]
    if ([string]::IsNullOrWhiteSpace($value)) { return @() }
    [void]$candidates.Add($value)
    $normalized = $value.Replace("/", ".").Replace("::", ".")
    if ($normalized -ne $value) { [void]$candidates.Add($normalized) }
    return @($candidates.ToArray() | Select-Object -Unique)
}

function Resolve-TagReference {
    param(
        [string]$Tag,
        [object[]]$DbMembers,
        [object[]]$LadReferences
    )
    $candidates = Get-ContractTargetCandidates -Tag $Tag
    foreach ($candidate in $candidates) {
        $exactMember = @($DbMembers | Where-Object {
            ($_.dbName + "." + $_.memberPath) -eq $candidate
        })
        if ($exactMember.Count -gt 0) {
            return [pscustomobject]@{
                status = "RESOLVED"
                match = "DB_MEMBER"
                target = $candidate
                detail = $exactMember[0].dbName + "." + $exactMember[0].memberPath
            }
        }
        $ladMatch = @($LadReferences | Where-Object {
            $_.referenceType -eq "GLOBAL_SYMBOL" -and $_.symbolPath -eq $candidate
        })
        if ($ladMatch.Count -gt 0) {
            return [pscustomobject]@{
                status = "RESOLVED"
                match = "LAD_GLOBAL_SYMBOL"
                target = $candidate
                detail = "Referenced by LAD"
            }
        }
    }

    $memberNameMatches = @($DbMembers | Where-Object {
        $_.memberName -eq ([string]$Tag).Trim() -or $_.memberPath -eq ([string]$Tag).Trim()
    })
    if ($memberNameMatches.Count -eq 1) {
        return [pscustomobject]@{
            status = "INFERRED"
            match = "UNIQUE_DB_MEMBER"
            target = $Tag
            detail = $memberNameMatches[0].dbName + "." + $memberNameMatches[0].memberPath
        }
    }

    return [pscustomobject]@{
        status = "UNRESOLVED"
        match = "NONE"
        target = $Tag
        detail = "No exact DB member or exported LAD global symbol was found."
    }
}

function Test-BilingualName {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return $false }
    return $Name -match "^[^_]+_[A-Za-z][A-Za-z0-9]*(?:_[A-Za-z0-9]+)*$" -and
        $Name -match "[^\x00-\x7F]"
}

function Add-Finding {
    param(
        [System.Collections.Generic.List[object]]$Findings,
        [string]$Severity,
        [string]$Category,
        [string]$Code,
        [string]$Subject,
        [string]$Message,
        [string]$SourcePath = "",
        [string]$Remediation = ""
    )
    [void]$Findings.Add([pscustomobject]@{
        severity = $Severity
        category = $Category
        code = $Code
        subject = $Subject
        message = $Message
        sourcePath = $SourcePath
        remediation = $Remediation
    })
}

function Test-ContractNaming {
    param(
        [System.Collections.Generic.List[object]]$Findings,
        [object[]]$Names,
        [string]$Category,
        [string]$SourcePath = ""
    )
    foreach ($item in $Names) {
        $name = [string]$item
        if ([string]::IsNullOrWhiteSpace($name)) { continue }
        if ($name -match "^(Static|Temp|Input|Output|InOut)_\d+$" -or $name -match "^Unnamed") {
            Add-Finding -Findings $Findings -Severity "FAIL" -Category "NAMING" `
                -Code "LOW_READABILITY_NAME" -Subject $name `
                -Message "名称使用了自动编号或占位符，无法稳定表达工艺语义。" `
                -SourcePath $SourcePath -Remediation "改为简洁的中文_English 名称，并在网络或接口处补充中文/English 注释。"
        }
        elseif (-not (Test-BilingualName -Name $name)) {
            Add-Finding -Findings $Findings -Severity "WARN" -Category "NAMING" `
                -Code "NOT_BILINGUAL" -Subject $name `
                -Message "名称未完全符合中文_English 规则。" `
                -SourcePath $SourcePath -Remediation "优先改为中文_English；系统保留名或 TIA 固有名可记录例外。"
        }
    }
}

function Get-OverallStatus {
    param([object[]]$Findings)
    if (@($Findings | Where-Object { $_.severity -eq "FAIL" }).Count -gt 0) { return "FAIL" }
    if (@($Findings | Where-Object { $_.severity -eq "WARN" }).Count -gt 0) { return "WARN" }
    return "PASS"
}

function Write-CsvUtf8 {
    param([string]$Path, [AllowNull()][object[]]$Rows)
    if ($null -eq $Rows -or @($Rows).Count -eq 0) {
        Set-Content -LiteralPath $Path -Value "" -Encoding UTF8
        return
    }
    @($Rows) | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding UTF8
}

$root = Resolve-ProjectDirectory -Path $ProjectPath
$workspaceRoot = Join-Path $root "PLC_Code"
if ([string]::IsNullOrWhiteSpace($WorkflowConfigPath)) {
    $WorkflowConfigPath = Join-Path $workspaceRoot "config\ai-workflow.json"
}
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $workspaceRoot "engineering-contracts\latest"
}
Ensure-Directory -Path $OutputDirectory

$blockListPath = Get-LatestBlockList -WorkspaceRoot $workspaceRoot
$blocks = Parse-BlockList -Path $blockListPath

if ([string]::IsNullOrWhiteSpace($ExportRoot)) {
    $ExportRoot = Join-Path $workspaceRoot "exports"
}
$xmlEntries = Get-UniqueXmlFiles -Root $ExportRoot
$dbMembers = Get-DbMembers -XmlEntries $xmlEntries

$blockRows = New-Object System.Collections.Generic.List[object]
foreach ($entry in $xmlEntries) {
    [void]$blockRows.Add([pscustomobject]@{
        name = Get-BlockName -BlockNode $entry.blockNode
        type = Get-BlockType -BlockNode $entry.blockNode
        number = Get-BlockNumber -BlockNode $entry.blockNode
        language = Get-ProgrammingLanguage -BlockNode $entry.blockNode
        sourceXml = $entry.file.FullName
    })
}
foreach ($block in $blocks) {
    if (@($blockRows | Where-Object { $_.name -eq $block.name }).Count -eq 0) {
        [void]$blockRows.Add([pscustomobject]@{
            name = $block.name
            type = $block.type
            number = $block.number
            language = $block.language
            sourceXml = ""
        })
    }
}
$blockRowsArray = @($blockRows.ToArray() | Sort-Object name,type,number -Unique)
$dbEvidence = Get-DbEvidence -Blocks $blocks -XmlEntries $xmlEntries -DbMembers $dbMembers
$ladReferences = Get-LadReferences -XmlEntries $xmlEntries -DbMembers $dbMembers `
    -Blocks $blockRowsArray -DbEvidence $dbEvidence

if ([string]::IsNullOrWhiteSpace($WinccPackagePath)) {
    $WinccPackagePath = Get-FirstExistingPath -Paths @(
        (Join-Path $workspaceRoot "wincc\engineering-scaffold\latest"),
        (Join-Path $workspaceRoot "wincc\openness-implementation\latest"),
        (Join-Path $workspaceRoot "wincc\tasks\latest")
    )
}
$hmiTagPath = Find-WinccFile -Root $WinccPackagePath -Name "hmi-tag-import-map.csv"
$alarmPath = Find-WinccFile -Root $WinccPackagePath -Name "alarm-import-map.csv"
$screenPath = Find-WinccFile -Root $WinccPackagePath -Name "screen-object-map.csv"
if ([string]::IsNullOrWhiteSpace($hmiTagPath)) {
    $hmiTagPath = Get-FirstExistingPath -Paths @(
        (Join-Path $workspaceRoot "wincc\engineering-scaffold\latest\hmi-tag-import-map.csv"),
        (Join-Path $workspaceRoot "wincc\openness-implementation\latest\hmi-tag-import-map.csv"),
        (Join-Path $workspaceRoot "wincc\tasks\latest\hmi-tag-import-map.csv")
    )
}
if ([string]::IsNullOrWhiteSpace($alarmPath)) {
    $alarmPath = Get-FirstExistingPath -Paths @(
        (Join-Path $workspaceRoot "wincc\engineering-scaffold\latest\alarm-import-map.csv"),
        (Join-Path $workspaceRoot "wincc\openness-implementation\latest\alarm-import-map.csv"),
        (Join-Path $workspaceRoot "wincc\tasks\latest\alarm-import-map.csv")
    )
}
if ([string]::IsNullOrWhiteSpace($screenPath)) {
    $screenPath = Get-FirstExistingPath -Paths @(
        (Join-Path $workspaceRoot "wincc\openness-implementation\latest\screen-object-map.csv"),
        (Join-Path $workspaceRoot "wincc\tasks\latest\screen-object-map.csv")
    )
}
$tagContractCandidates = @(
    (Join-Path $workspaceRoot "wincc\design-workflow\latest\tag-contract.md"),
    (Join-Path $workspaceRoot "wincc\tasks\latest\tag-contract.md")
)
if (-not [string]::IsNullOrWhiteSpace($WinccPackagePath)) {
    $tagContractCandidates = @(
        (Join-Path $WinccPackagePath "tag-contract.md")
    ) + $tagContractCandidates
}
$tagContractPath = Get-FirstExistingPath -Paths $tagContractCandidates

$hmiTags = Import-CsvSafe -Path $hmiTagPath
$alarms = Import-CsvSafe -Path $alarmPath
$screenObjects = Import-CsvSafe -Path $screenPath
$tagContractBindings = Import-TagContractBindings -Path $tagContractPath
$findings = New-Object System.Collections.Generic.List[object]
$hmiReferences = New-Object System.Collections.Generic.List[object]
$alarmReferences = New-Object System.Collections.Generic.List[object]

foreach ($group in @($ladReferences |
    Where-Object { $_.referenceType -eq "DB_MEMBER" -and -not $_.exists } |
    Group-Object symbolPath)) {
    $reference = $group.Group[0]
    if ($reference.evidenceStatus -eq "MISSING_MEMBER") {
        Add-Finding -Findings $findings -Severity "FAIL" -Category "PLC_REFERENCE" `
            -Code "MISSING_DB_MEMBER" -Subject $reference.symbolPath `
            -Message ("LAD 引用了不存在的 DB 成员；出现 {0} 次，示例位置为 {1} 网络 {2}。" -f $group.Count,$reference.blockName,$reference.network) `
            -SourcePath $reference.sourceXml -Remediation "检查 DB 名称、成员路径和导出版本；先修复 DB 契约，再重新编译克隆工程。"
    }
    else {
        Add-Finding -Findings $findings -Severity "WARN" -Category "EVIDENCE_GAP" `
            -Code "UNVERIFIED_DB_MEMBER" -Subject $reference.symbolPath `
            -Message ("DB 块已在工程清单中找到，但没有成员 XML 证据；出现 {0} 次，示例位置为 {1} 网络 {2}。当前不能判定成员不存在。" -f $group.Count,$reference.blockName,$reference.network) `
            -SourcePath $reference.evidenceSource -Remediation "重新导出该 DB，或在克隆验证前补充 DB 成员 XML/Openness 回读证据。"
    }
}
foreach ($group in @($ladReferences |
    Where-Object { $_.referenceType -eq "INSTRUCTION" -and -not $_.exists -and -not [string]::IsNullOrWhiteSpace($_.instance) } |
    Group-Object instruction,instance)) {
    $reference = $group.Group[0]
    Add-Finding -Findings $findings -Severity "WARN" -Category "EVIDENCE_GAP" `
        -Code "UNVERIFIED_INSTANCE_DB" -Subject $reference.instance `
        -Message ("指令 {0} 的实例 DB 在当前导出证据中未确认；出现 {1} 次，来源类别为 {2}。这不等同于实例 DB 已确认缺失。" -f $reference.instruction,$group.Count,$reference.originClass) `
        -SourcePath $reference.sourceXml -Remediation "优先导出实例 DB或保留 supporting-sources；再通过克隆工程编译确认实例是否可用。"
}

foreach ($tag in $hmiTags) {
    $objectName = [string]$tag.objectName
    $tagName = [string]$tag.tag
    $binding = Get-TagBinding -TagObject $tag -ContractBindings $tagContractBindings
    $bindingTarget = if ($binding.value) { [string]$binding.value } else { $tagName }
    $resolution = Resolve-TagReference -Tag $bindingTarget -DbMembers $dbMembers -LadReferences $ladReferences
    $referenceStatus = [string]$resolution.status
    [void]$hmiReferences.Add([pscustomobject]@{
        objectName = $objectName
        tag = $tagName
        binding = [string]$binding.value
        bindingSource = [string]$binding.source
        layer = [string]$tag.layer
        access = [string]$tag.access
        datatype = Get-OptionalPropertyValue -Object $tag -Names @("datatype", "dataType", "type")
        confirmation = [string]$tag.confirmation
        resolution = $referenceStatus
        match = [string]$resolution.match
        resolvedTarget = [string]$resolution.detail
        source = if ($hmiTagPath) { $hmiTagPath } else { "" }
    })
    if ($referenceStatus -eq "UNRESOLVED") {
        $severity = if ([string]$tag.access -eq "write") { "FAIL" } else { "WARN" }
        $findingSource = if ($binding.source) { $binding.source } else { $hmiTagPath }
        Add-Finding -Findings $findings -Severity $severity -Category "HMI_REFERENCE" `
            -Code "UNRESOLVED_HMI_TAG" -Subject $tagName `
            -Message ("WinCC 标签 {0} 的 PLC 绑定 {1} 未解析到当前导出的 DB 成员或 LAD 全局符号。" -f $tagName,$bindingTarget) `
            -SourcePath $findingSource `
            -Remediation "在 CSV 增加 plcPath/binding，或在 tag-contract.md 增加 PLC Binding 列，并绑定到明确的 DB.Member 或已回读的 PLC 全局符号。"
    }
    elseif ($referenceStatus -eq "INFERRED") {
        Add-Finding -Findings $findings -Severity "WARN" -Category "HMI_REFERENCE" `
            -Code "INFERRED_HMI_TAG" -Subject $tagName `
            -Message ("WinCC 标签 {0} 仅通过唯一成员名推断绑定目标。" -f $tagName) `
            -SourcePath $hmiTagPath -Remediation "在标签清单中写入完整 DB.Member 路径，避免 DB 增加同名成员后发生漂移。"
    }
    if ([string]$tag.access -eq "write" -and [string]::IsNullOrWhiteSpace([string]$tag.confirmation)) {
        Add-Finding -Findings $findings -Severity "FAIL" -Category "SAFETY" `
            -Code "WRITE_WITHOUT_CONFIRMATION" -Subject $tagName `
            -Message "WinCC 写入标签没有记录权限、模式或确认策略。" `
            -SourcePath $hmiTagPath -Remediation "补充 authority-and-range、mode-authority 或明确的安全确认策略。"
    }
}

foreach ($alarm in $alarms) {
    $trigger = [string]$alarm.triggerTag
    $binding = Get-TagBinding -TagObject $alarm -ContractBindings $tagContractBindings
    $bindingTarget = if ($binding.value) { [string]$binding.value } else { $trigger }
    $resolution = Resolve-TagReference -Tag $bindingTarget -DbMembers $dbMembers -LadReferences $ladReferences
    [void]$alarmReferences.Add([pscustomobject]@{
        alarmName = [string]$alarm.alarmName
        class = [string]$alarm.class
        triggerTag = $trigger
        binding = [string]$binding.value
        bindingSource = [string]$binding.source
        datatype = Get-OptionalPropertyValue -Object $alarm -Names @("datatype", "dataType", "type")
        ack = [string]$alarm.ack
        reset = [string]$alarm.reset
        resolution = [string]$resolution.status
        resolvedTarget = [string]$resolution.detail
        source = if ($alarmPath) { $alarmPath } else { "" }
    })
    if ($resolution.status -eq "UNRESOLVED") {
        $findingSource = if ($binding.source) { $binding.source } else { $alarmPath }
        Add-Finding -Findings $findings -Severity "FAIL" -Category "HMI_REFERENCE" `
            -Code "UNRESOLVED_ALARM_TRIGGER" -Subject $trigger `
            -Message ("报警 {0} 的 PLC 触发绑定 {1} 未解析。" -f [string]$alarm.alarmName,$bindingTarget) `
            -SourcePath $findingSource `
            -Remediation "在报警清单增加 plcPath/binding，或在 tag-contract.md 增加 PLC Binding 列，并固定完整路径。"
    }
    if ([string]::IsNullOrWhiteSpace([string]$alarm.ack) -or [string]::IsNullOrWhiteSpace([string]$alarm.reset)) {
        Add-Finding -Findings $findings -Severity "WARN" -Category "SAFETY" `
            -Code "ALARM_POLICY_INCOMPLETE" -Subject ([string]$alarm.alarmName) `
            -Message "报警缺少确认或复位策略。" `
            -SourcePath $alarmPath -Remediation "明确 ack、reset、首出故障和现场条件恢复策略。"
    }
}

$allHmiTags = @($hmiTags | ForEach-Object { [string]$_.tag })
foreach ($screen in $screenObjects) {
    $screenTags = @(([string]$screen.tags) -split ";") | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    foreach ($screenTag in $screenTags) {
        $resolution = Resolve-TagReference -Tag $screenTag.Trim() -DbMembers $dbMembers -LadReferences $ladReferences
        if ($resolution.status -eq "UNRESOLVED" -and $allHmiTags -notcontains $screenTag.Trim()) {
            Add-Finding -Findings $findings -Severity "WARN" -Category "WINCC_SCREEN" `
                -Code "SCREEN_TAG_NOT_IN_IMPORT_MAP" -Subject $screenTag.Trim() `
                -Message ("画面对象 {0} 使用的标签既不在 HMI 导入表中，也未在 PLC 导出证据中解析。" -f $screenTag.Trim()) `
                -SourcePath $screenPath -Remediation "把画面绑定标签加入 HMI tag contract，并确认读写权限与数据类型。"
        }
    }
}

$nameValues = New-Object System.Collections.Generic.List[string]
foreach ($value in @($blockRowsArray | Select-Object -ExpandProperty name)) { [void]$nameValues.Add([string]$value) }
foreach ($value in @($dbMembers | ForEach-Object { $_.memberName })) { [void]$nameValues.Add([string]$value) }
foreach ($value in @($hmiTags | ForEach-Object { $_.objectName; $_.tag })) { [void]$nameValues.Add([string]$value) }
foreach ($value in @($alarms | ForEach-Object { $_.alarmName; $_.triggerTag })) { [void]$nameValues.Add([string]$value) }
foreach ($value in @($screenObjects | ForEach-Object { $_.screenName; $_.component })) { [void]$nameValues.Add([string]$value) }
Test-ContractNaming -Findings $findings -Names @($nameValues | Select-Object -Unique) -Category "NAMING"

foreach ($tag in $hmiTags | Where-Object { [string]$_.access -eq "write" }) {
    $tagName = [string]$tag.tag
    $relatedFeedback = @($hmiTags | Where-Object {
        [string]$_.layer -in @("Fb", "Sts") -and
        (([string]$_.tag) -match "Fb|Sts|状态|反馈")
    })
    if ($relatedFeedback.Count -eq 0) {
        Add-Finding -Findings $findings -Severity "WARN" -Category "SAFETY" `
            -Code "COMMAND_WITHOUT_FEEDBACK_CONTEXT" -Subject $tagName `
            -Message "当前 HMI 写入清单未找到可关联的反馈/状态标签。" `
            -SourcePath $hmiTagPath -Remediation "为命令配套反馈、互锁允许和禁用原因，避免按钮状态代表真实设备状态。"
    }
    if ($tagName -match "复位|回零|配方|强制|Reset|Home|Recipe|Force") {
        if ([string]::IsNullOrWhiteSpace([string]$tag.confirmation) -or
            [string]$tag.confirmation -match "none|无") {
            Add-Finding -Findings $findings -Severity "FAIL" -Category "SAFETY" `
                -Code "HIGH_RISK_WRITE_UNGATED" -Subject $tagName `
                -Message "复位、回零、配方或强制类写入缺少高风险门禁。" `
                -SourcePath $hmiTagPath -Remediation "增加用户等级、模式许可、范围校验、二次确认和动作反馈。"
        }
    }
}

$xmlEntryArray = @($xmlEntries)
$blockArray = @($blocks)
$blockRowArray = @($blockRowsArray)
$dbMemberArray = @($dbMembers)
$dbEvidenceArray = @($dbEvidence)
$ladReferenceArray = @($ladReferences)
$hmiTagArray = @($hmiTags)
$alarmArray = @($alarms)
$screenObjectArray = @($screenObjects)
$findingArray = $findings.ToArray()
$contractStatus = Get-OverallStatus -Findings $findingArray
$contractFailCount = @($findingArray | Where-Object { $_.severity -eq "FAIL" }).Count
$contractWarnCount = @($findingArray | Where-Object { $_.severity -eq "WARN" }).Count
$contractUnverifiedCount = @($findingArray | Where-Object { $_.category -eq "EVIDENCE_GAP" }).Count
$dbBlocksWithMemberEvidence = @($dbEvidenceArray | Where-Object { $_.memberEvidenceCount -gt 0 }).Count
$dbEvidenceGapCount = @($dbEvidenceArray | Where-Object { $_.confidence -ne "VERIFIED" }).Count

$summary = [pscustomobject]@{
    status = $contractStatus
    generatedAt = (Get-Date).ToString("o")
    projectRoot = $root
    tiaVersion = ""
    workflowConfigPath = $WorkflowConfigPath
    blockListPath = $blockListPath
    exportRoot = $ExportRoot
    winccPackagePath = $WinccPackagePath
    sources = [pscustomobject]@{
        xmlFiles = $xmlEntryArray.Count
        blockListRows = $blockArray.Count
        blocks = $blockRowArray.Count
        dbBlocks = $dbEvidenceArray.Count
        dbBlocksWithMemberEvidence = $dbBlocksWithMemberEvidence
        dbMembers = $dbMemberArray.Count
        dbEvidenceGaps = $dbEvidenceGapCount
        ladReferences = $ladReferenceArray.Count
        hmiTags = $hmiTagArray.Count
        alarms = $alarmArray.Count
        screenObjects = $screenObjectArray.Count
        tagContractBindings = $tagContractBindings.Count
    }
    findings = [pscustomobject]@{
        total = $findingArray.Count
        fail = $contractFailCount
        warn = $contractWarnCount
        unverified = $contractUnverifiedCount
        pass = 0
    }
    namingRule = "中文_English"
    productionWriteAllowed = $false
    plcDownloadAllowed = $false
}

$report = [pscustomobject]@{
    schemaVersion = 2
    summary = $summary
    blocks = $blockRowArray
    dbEvidence = $dbEvidenceArray
    dbMembers = $dbMemberArray
    ladReferences = $ladReferenceArray
    hmiPlcReferences = $hmiReferences.ToArray()
    alarmReferences = $alarmReferences.ToArray()
    findings = $findingArray
    sourceFiles = [pscustomobject]@{
        blockList = $blockListPath
        xmlRoot = $ExportRoot
        hmiTags = $hmiTagPath
        alarms = $alarmPath
        screens = $screenPath
        tagContract = $tagContractPath
    }
}

$jsonPath = Join-Path $OutputDirectory "engineering-contract-report.json"
$mdPath = Join-Path $OutputDirectory "engineering-contract-report.md"
$blockIndexPath = Join-Path $OutputDirectory "block-reference-index.csv"
$dbEvidenceIndexPath = Join-Path $OutputDirectory "db-evidence-index.csv"
$dbIndexPath = Join-Path $OutputDirectory "db-member-index.csv"
$hmiIndexPath = Join-Path $OutputDirectory "hmi-plc-reference-index.csv"
$namingPath = Join-Path $OutputDirectory "naming-findings.csv"
$safetyPath = Join-Path $OutputDirectory "safety-findings.csv"

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
Write-CsvUtf8 -Path $blockIndexPath -Rows $ladReferences
Write-CsvUtf8 -Path $dbEvidenceIndexPath -Rows $dbEvidenceArray
Write-CsvUtf8 -Path $dbIndexPath -Rows $dbMembers
Write-CsvUtf8 -Path $hmiIndexPath -Rows $hmiReferences.ToArray()
Write-CsvUtf8 -Path $namingPath -Rows @($findings | Where-Object { $_.category -eq "NAMING" })
Write-CsvUtf8 -Path $safetyPath -Rows @($findings | Where-Object { $_.category -eq "SAFETY" })

$md = New-Object System.Text.StringBuilder
[void]$md.AppendLine("# PLC-DB-WinCC 工程契约报告")
[void]$md.AppendLine()
[void]$md.AppendLine("- 状态: **$($summary.status)**")
[void]$md.AppendLine("- 工程: ``$root``")
[void]$md.AppendLine("- 生成时间: ``$($summary.generatedAt)``")
[void]$md.AppendLine("- 命名规则: ``中文_English``")
[void]$md.AppendLine("- 生产写入: ``false``；PLC下载: ``false``")
[void]$md.AppendLine()
[void]$md.AppendLine("## 证据统计")
[void]$md.AppendLine()
[void]$md.AppendLine("| 项目 | 数量 |")
[void]$md.AppendLine("| --- | ---: |")
[void]$md.AppendLine("| XML块文件 | $($summary.sources.xmlFiles) |")
[void]$md.AppendLine("| 程序块 | $($summary.sources.blocks) |")
[void]$md.AppendLine("| DB块 | $($summary.sources.dbBlocks) |")
[void]$md.AppendLine("| 有成员证据的DB块 | $($summary.sources.dbBlocksWithMemberEvidence) |")
[void]$md.AppendLine("| DB成员 | $($summary.sources.dbMembers) |")
[void]$md.AppendLine("| DB证据缺口 | $($summary.sources.dbEvidenceGaps) |")
[void]$md.AppendLine("| LAD/FBD引用 | $($summary.sources.ladReferences) |")
[void]$md.AppendLine("| HMI标签 | $($summary.sources.hmiTags) |")
[void]$md.AppendLine("| HMI报警 | $($summary.sources.alarms) |")
[void]$md.AppendLine("| 画面对象 | $($summary.sources.screenObjects) |")
[void]$md.AppendLine()
[void]$md.AppendLine("## 结果统计")
[void]$md.AppendLine()
[void]$md.AppendLine("- FAIL: ``$($summary.findings.fail)``")
[void]$md.AppendLine("- WARN: ``$($summary.findings.warn)``")
[void]$md.AppendLine("- 其中证据缺口: ``$($summary.findings.unverified)``（不等同于工程错误）")
[void]$md.AppendLine()
[void]$md.AppendLine("## 失败项")
[void]$md.AppendLine()
$failFindings = @($findings | Where-Object { $_.severity -eq "FAIL" })
if ($failFindings.Count -eq 0) {
    [void]$md.AppendLine("无。")
}
else {
    [void]$md.AppendLine("| 类别 | 代码 | 对象 | 说明 |")
    [void]$md.AppendLine("| --- | --- | --- | --- |")
    foreach ($finding in $failFindings) {
        [void]$md.AppendLine("| $($finding.category) | ``$($finding.code)`` | $($finding.subject) | $($finding.message) |")
    }
}
[void]$md.AppendLine()
[void]$md.AppendLine("## 警告项")
[void]$md.AppendLine()
$warnFindings = @($findings | Where-Object { $_.severity -eq "WARN" })
if ($warnFindings.Count -eq 0) {
    [void]$md.AppendLine("无。")
}
else {
    [void]$md.AppendLine("| 类别 | 代码 | 对象 | 说明 |")
    [void]$md.AppendLine("| --- | --- | --- | --- |")
    foreach ($finding in ($warnFindings | Select-Object -First 80)) {
        [void]$md.AppendLine("| $($finding.category) | ``$($finding.code)`` | $($finding.subject) | $($finding.message) |")
    }
    if ($warnFindings.Count -gt 80) {
        [void]$md.AppendLine()
        [void]$md.AppendLine("其余警告见 ``naming-findings.csv``、``safety-findings.csv`` 和 JSON 报告。")
    }
}
[void]$md.AppendLine()
[void]$md.AppendLine("## 输出文件")
[void]$md.AppendLine()
foreach ($path in @($jsonPath,$blockIndexPath,$dbEvidenceIndexPath,$dbIndexPath,$hmiIndexPath,$namingPath,$safetyPath)) {
    [void]$md.AppendLine("- ``$path``")
}
$md.ToString() | Set-Content -LiteralPath $mdPath -Encoding UTF8

[pscustomobject]@{
    status = "ok"
    contractStatus = $summary.status
    outputDirectory = $OutputDirectory
    report = $mdPath
    reportJson = $jsonPath
    blockReferenceIndex = $blockIndexPath
    dbEvidenceIndex = $dbEvidenceIndexPath
    dbMemberIndex = $dbIndexPath
    hmiPlcReferenceIndex = $hmiIndexPath
    namingFindings = $namingPath
    safetyFindings = $safetyPath
    counts = $summary.sources
    findingCounts = $summary.findings
} | ConvertTo-Json -Depth 8
