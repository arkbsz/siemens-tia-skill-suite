param(
    [Parameter(Mandatory = $true)]
    [string]$SourceXml,

    [Parameter(Mandatory = $true)]
    [string]$OutputXml,

    [int]$NetworkIndex = 0,

    [string[]]$Replace = @(),

    [string]$Title,

    [string]$Comment
)

$ErrorActionPreference = "Stop"

function Select-CompileUnits {
    param([System.Xml.XmlNode]$Node)
    return @($Node.SelectNodes(".//*[local-name()='CompileUnit' or local-name()='SW.Blocks.CompileUnit']"))
}

function Get-Attr {
    param([System.Xml.XmlNode]$Node, [string]$Name)
    if ($Node.Attributes -and $Node.Attributes[$Name]) { return $Node.Attributes[$Name].Value }
    return $null
}

function Set-CompositionText {
    param(
        [System.Xml.XmlNode]$Unit,
        [string]$CompositionName,
        [string]$Value
    )

    $textNode = $Unit.SelectSingleNode("./*[local-name()='ObjectList']/*[local-name()='MultilingualText' and @CompositionName='$CompositionName']//*[local-name()='Text']")
    if (-not $textNode) {
        throw "Cannot find $CompositionName text node in selected network. Create the title/comment once in TIA, then export again."
    }
    $textNode.InnerText = $Value
}

function Get-SymbolText {
    param([System.Xml.XmlNode]$SymbolNode)
    $parts = @($SymbolNode.SelectNodes("./*[local-name()='Component']") | ForEach-Object { Get-Attr -Node $_ -Name "Name" } | Where-Object { $_ })
    return ($parts -join ".")
}

function Set-SymbolText {
    param(
        [System.Xml.XmlNode]$SymbolNode,
        [string]$Value
    )

    $namespace = $SymbolNode.NamespaceURI
    foreach ($child in @($SymbolNode.ChildNodes)) {
        $null = $SymbolNode.RemoveChild($child)
    }

    foreach ($part in $Value.Split(".")) {
        $component = $SymbolNode.OwnerDocument.CreateElement("Component", $namespace)
        $component.SetAttribute("Name", $part)
        $null = $SymbolNode.AppendChild($component)
    }
}

function Parse-Replacements {
    param([string[]]$Pairs)
    $map = @{}
    $expandedPairs = New-Object System.Collections.Generic.List[string]
    foreach ($rawPair in $Pairs) {
        foreach ($pairPart in ($rawPair -split ";")) {
            if ($pairPart.Trim()) { $expandedPairs.Add($pairPart.Trim()) }
        }
    }

    foreach ($pair in $expandedPairs) {
        $idx = $pair.IndexOf("=")
        if ($idx -le 0) { throw "Invalid replacement '$pair'. Use old=new." }
        $old = $pair.Substring(0, $idx)
        $new = $pair.Substring($idx + 1)
        if (-not $old -or -not $new) { throw "Invalid replacement '$pair'. Use old=new." }
        $map[$old] = $new
    }
    return $map
}

if (-not (Test-Path -LiteralPath $SourceXml)) { throw "Source XML not found: $SourceXml" }

$xml = New-Object System.Xml.XmlDocument
$xml.PreserveWhitespace = $true
$xml.Load((Get-Item -LiteralPath $SourceXml).FullName)
$units = Select-CompileUnits -Node $xml
if ($units.Count -eq 0) { throw "No LAD/FBD compile units found in $SourceXml" }

$targets = if ($NetworkIndex -gt 0) {
    if ($NetworkIndex -gt $units.Count) { throw "NetworkIndex $NetworkIndex exceeds network count $($units.Count)" }
    @($units[$NetworkIndex - 1])
} else {
    $units
}

$replacementMap = Parse-Replacements -Pairs $Replace
$changedSymbols = New-Object System.Collections.Generic.List[string]

foreach ($unit in $targets) {
    foreach ($symbolNode in @($unit.SelectNodes(".//*[local-name()='Symbol']"))) {
        $current = Get-SymbolText -SymbolNode $symbolNode
        if ($replacementMap.ContainsKey($current)) {
            Set-SymbolText -SymbolNode $symbolNode -Value $replacementMap[$current]
            $changedSymbols.Add("$current -> $($replacementMap[$current])")
        }
    }

    if ($PSBoundParameters.ContainsKey("Title")) {
        Set-CompositionText -Unit $unit -CompositionName "Title" -Value $Title
    }
    if ($PSBoundParameters.ContainsKey("Comment")) {
        Set-CompositionText -Unit $unit -CompositionName "Comment" -Value $Comment
    }
}

$outDir = Split-Path -Parent $OutputXml
if ($outDir) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
$settings = New-Object System.Xml.XmlWriterSettings
$settings.Encoding = New-Object System.Text.UTF8Encoding($false)
$settings.Indent = $true
$writer = [System.Xml.XmlWriter]::Create($OutputXml, $settings)
$xml.Save($writer)
$writer.Close()

[pscustomobject]@{
    SourceXml = (Get-Item -LiteralPath $SourceXml).FullName
    OutputXml = (Get-Item -LiteralPath $OutputXml).FullName
    NetworkIndex = $NetworkIndex
    ChangedSymbols = @($changedSymbols)
    TitleChanged = $PSBoundParameters.ContainsKey("Title")
    CommentChanged = $PSBoundParameters.ContainsKey("Comment")
} | ConvertTo-Json -Depth 5
