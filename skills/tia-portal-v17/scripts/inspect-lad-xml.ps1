param(
    [Parameter(Mandatory = $true)]
    [string]$Path
)

$ErrorActionPreference = "Stop"

function Select-LocalNodes {
    param(
        [System.Xml.XmlNode]$Node,
        [string]$LocalName
    )

    return $Node.SelectNodes(".//*[local-name()='$LocalName']")
}

function Select-TiaCompileUnits {
    param([System.Xml.XmlNode]$Node)

    return $Node.SelectNodes(".//*[local-name()='CompileUnit' or local-name()='SW.Blocks.CompileUnit']")
}

function Get-Attr {
    param(
        [System.Xml.XmlNode]$Node,
        [string]$Name
    )

    if ($Node.Attributes -and $Node.Attributes[$Name]) {
        return $Node.Attributes[$Name].Value
    }

    return $null
}

$files = if ((Get-Item -LiteralPath $Path).PSIsContainer) {
    Get-ChildItem -LiteralPath $Path -Recurse -File | Where-Object { $_.Extension -ieq ".xml" }
} else {
    @(Get-Item -LiteralPath $Path)
}

if (@($files).Count -eq 0) {
    [pscustomobject]@{
        Path = (Get-Item -LiteralPath $Path).FullName
        Files = 0
        Message = "No XML files found."
    } | ConvertTo-Json -Depth 4
    exit 0
}

$result = foreach ($file in $files) {
    $xml = New-Object System.Xml.XmlDocument
    $xml.PreserveWhitespace = $true
    $xml.Load($file.FullName)
    $compileUnits = @(Select-TiaCompileUnits -Node $xml)
    $parts = @(Select-LocalNodes -Node $xml -LocalName "Part")
    $wires = @(Select-LocalNodes -Node $xml -LocalName "Wire")
    $accesses = @(Select-LocalNodes -Node $xml -LocalName "Access")
    $flgNets = @(Select-LocalNodes -Node $xml -LocalName "FlgNet")
    $languageNode = $xml.SelectSingleNode("//*[local-name()='ProgrammingLanguage']")

    $partNames = @($parts | ForEach-Object {
        $name = Get-Attr -Node $_ -Name "Name"
        if (-not $name) { $name = Get-Attr -Node $_ -Name "UId" }
        $name
    } | Where-Object { $_ } | Sort-Object -Unique)

    $symbols = @($accesses | ForEach-Object {
        $symbolNode = $_.SelectSingleNode(".//*[local-name()='Symbol']")
        if ($symbolNode) {
            ($symbolNode.SelectNodes(".//*[local-name()='Component']") | ForEach-Object {
                Get-Attr -Node $_ -Name "Name"
            }) -join "."
        }
    } | Where-Object { $_ } | Sort-Object -Unique)

    $networks = @()
    $index = 0
    foreach ($unit in $compileUnits) {
        $index++
        $unitParts = @(Select-LocalNodes -Node $unit -LocalName "Part")
        $unitWires = @(Select-LocalNodes -Node $unit -LocalName "Wire")
        $networks += [pscustomobject]@{
            Index = $index
            ID = Get-Attr -Node $unit -Name "ID"
            CompositionName = Get-Attr -Node $unit -Name "CompositionName"
            Parts = $unitParts.Count
            Wires = $unitWires.Count
        }
    }

    [pscustomobject]@{
        File = $file.FullName
        ProgrammingLanguage = if ($languageNode) { $languageNode.InnerText } else { $null }
        CompileUnits = $compileUnits.Count
        FlgNets = $flgNets.Count
        Parts = $parts.Count
        Wires = $wires.Count
        Accesses = $accesses.Count
        PartNames = $partNames
        Symbols = $symbols
        Networks = $networks
    }
}

$result | ConvertTo-Json -Depth 8
