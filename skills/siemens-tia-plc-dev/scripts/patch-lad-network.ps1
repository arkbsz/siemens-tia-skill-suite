param(
    [Parameter(Mandatory = $true)]
    [string]$TargetXml,

    [Parameter(Mandatory = $true)]
    [string]$DonorXml,

    [Parameter(Mandatory = $true)]
    [string]$OutputXml,

    [Parameter(Mandatory = $true)]
    [int]$TargetNetworkIndex,

    [int]$DonorNetworkIndex = 0,

    [switch]$CopyTitle,

    [switch]$CopyComment
)

$ErrorActionPreference = "Stop"

function Get-XmlDocument {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "XML file not found: $Path"
    }

    $xml = New-Object System.Xml.XmlDocument
    $xml.PreserveWhitespace = $true
    $xml.Load((Get-Item -LiteralPath $Path).FullName)
    return $xml
}

function Select-CompileUnits {
    param([System.Xml.XmlNode]$Node)
    return @($Node.SelectNodes(".//*[local-name()='CompileUnit' or local-name()='SW.Blocks.CompileUnit']"))
}

function Get-NetworkUnit {
    param(
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlNode[]]$Units,

        [Parameter(Mandatory = $true)]
        [int]$Index,

        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    if ($Index -lt 1) {
        throw "$Label must be greater than 0."
    }
    if ($Index -gt $Units.Count) {
        throw "$Label $Index exceeds network count $($Units.Count)."
    }

    return $Units[$Index - 1]
}

function Replace-ChildNode {
    param(
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlNode]$Parent,

        [Parameter(Mandatory = $true)]
        [System.Xml.XmlNode]$NewChild,

        [Parameter(Mandatory = $true)]
        [string]$LocalName
    )

    $existing = $Parent.SelectSingleNode("./*[local-name()='$LocalName']")
    $imported = $Parent.OwnerDocument.ImportNode($NewChild, $true)

    if ($existing) {
        $null = $Parent.ReplaceChild($imported, $existing)
    }
    else {
        $null = $Parent.AppendChild($imported)
    }
}

function Copy-CompositionText {
    param(
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlNode]$TargetUnit,

        [Parameter(Mandatory = $true)]
        [System.Xml.XmlNode]$DonorUnit,

        [Parameter(Mandatory = $true)]
        [string]$CompositionName
    )

    $targetText = $TargetUnit.SelectSingleNode("./*[local-name()='ObjectList']/*[local-name()='MultilingualText' and @CompositionName='$CompositionName']//*[local-name()='Text']")
    $donorText = $DonorUnit.SelectSingleNode("./*[local-name()='ObjectList']/*[local-name()='MultilingualText' and @CompositionName='$CompositionName']//*[local-name()='Text']")

    if (-not $donorText) {
        return $false
    }
    if (-not $targetText) {
        throw "Cannot find target $CompositionName text node. Create it once in TIA, export again, then retry."
    }

    $targetText.InnerText = $donorText.InnerText
    return $true
}

$resolvedTarget = (Get-Item -LiteralPath $TargetXml).FullName
$resolvedDonor = (Get-Item -LiteralPath $DonorXml).FullName

$targetDoc = Get-XmlDocument -Path $resolvedTarget
$donorDoc = Get-XmlDocument -Path $resolvedDonor

$targetUnits = Select-CompileUnits -Node $targetDoc
$donorUnits = Select-CompileUnits -Node $donorDoc

if ($targetUnits.Count -eq 0) {
    throw "No compile units found in target XML: $resolvedTarget"
}
if ($donorUnits.Count -eq 0) {
    throw "No compile units found in donor XML: $resolvedDonor"
}

$resolvedDonorNetworkIndex = if ($DonorNetworkIndex -gt 0) { $DonorNetworkIndex } else { $TargetNetworkIndex }

$targetUnit = Get-NetworkUnit -Units $targetUnits -Index $TargetNetworkIndex -Label "TargetNetworkIndex"
$donorUnit = Get-NetworkUnit -Units $donorUnits -Index $resolvedDonorNetworkIndex -Label "DonorNetworkIndex"

$targetAttributeList = $targetUnit.SelectSingleNode("./*[local-name()='AttributeList']")
$donorAttributeList = $donorUnit.SelectSingleNode("./*[local-name()='AttributeList']")
if (-not $targetAttributeList -or -not $donorAttributeList) {
    throw "Target or donor network does not contain an AttributeList node."
}

$donorNetworkSource = $donorAttributeList.SelectSingleNode("./*[local-name()='NetworkSource']")
if (-not $donorNetworkSource) {
    throw "Donor network does not contain a NetworkSource node."
}

Replace-ChildNode -Parent $targetAttributeList -NewChild $donorNetworkSource -LocalName "NetworkSource"

$titleCopied = $false
$commentCopied = $false
if ($CopyTitle) {
    $titleCopied = Copy-CompositionText -TargetUnit $targetUnit -DonorUnit $donorUnit -CompositionName "Title"
}
if ($CopyComment) {
    $commentCopied = Copy-CompositionText -TargetUnit $targetUnit -DonorUnit $donorUnit -CompositionName "Comment"
}

$outputDir = Split-Path -Parent $OutputXml
if ($outputDir) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$settings = New-Object System.Xml.XmlWriterSettings
$settings.Encoding = New-Object System.Text.UTF8Encoding($false)
$settings.Indent = $true
$writer = [System.Xml.XmlWriter]::Create($OutputXml, $settings)
$targetDoc.Save($writer)
$writer.Close()

[pscustomobject]@{
    TargetXml = $resolvedTarget
    DonorXml = $resolvedDonor
    OutputXml = (Get-Item -LiteralPath $OutputXml).FullName
    TargetNetworkIndex = $TargetNetworkIndex
    DonorNetworkIndex = $resolvedDonorNetworkIndex
    CopiedNetworkSource = $true
    CopiedTitle = $titleCopied
    CopiedComment = $commentCopied
} | ConvertTo-Json -Depth 5
