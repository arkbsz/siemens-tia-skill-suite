param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [string]$SchemaRoot = "C:\Program Files\Siemens\Automation\Portal V17\PublicAPI\V17\Schemas"
)

$ErrorActionPreference = "Stop"

$files = if ((Get-Item -LiteralPath $Path).PSIsContainer) {
    Get-ChildItem -LiteralPath $Path -Recurse -File | Where-Object { $_.Extension -ieq ".xml" }
} else {
    @(Get-Item -LiteralPath $Path)
}

if (@($files).Count -eq 0) {
    [pscustomobject]@{
        Path = (Get-Item -LiteralPath $Path).FullName
        Files = 0
        Ok = $true
        Message = "No XML files found."
    } | ConvertTo-Json -Depth 4
    exit 0
}

$schemaFiles = @(
    "SW.Common_v3.xsd",
    "SW.PlcBlocks.CompileUnitCommon_v4.xsd",
    "SW.PlcBlocks.Graph_v5.xsd",
    "SW.PlcBlocks.LADFBD_v4.xsd",
    "SW.PlcBlocks.Access_v4.xsd"
) | ForEach-Object { Join-Path $SchemaRoot $_ }

$results = foreach ($file in $files) {
    $issues = New-Object System.Collections.Generic.List[string]
    $schemaStatus = "not-run"
    $compileUnitCount = 0
    $flgNetCount = 0
    $partCount = 0
    $wireCount = 0
    $language = $null

    try {
        $xml = New-Object System.Xml.XmlDocument
        $xml.PreserveWhitespace = $true
        $xml.Load($file.FullName)
        $compileUnits = $xml.SelectNodes("//*[local-name()='CompileUnit' or local-name()='SW.Blocks.CompileUnit']")
        $flgNets = $xml.SelectNodes("//*[local-name()='FlgNet']")
        $parts = $xml.SelectNodes("//*[local-name()='Part']")
        $wires = $xml.SelectNodes("//*[local-name()='Wire']")
        $languageNode = $xml.SelectSingleNode("//*[local-name()='ProgrammingLanguage']")
        if ($languageNode) { $language = $languageNode.InnerText }
        $compileUnitCount = $compileUnits.Count
        $flgNetCount = $flgNets.Count
        $partCount = $parts.Count
        $wireCount = $wires.Count

        if ($xml.DocumentElement.LocalName -ne "Document") {
            $issues.Add("Root element is '$($xml.DocumentElement.LocalName)', expected TIA Openness Document")
        }
        if ($compileUnits.Count -eq 0) {
            $issues.Add("No CompileUnit/SW.Blocks.CompileUnit elements found")
        }
        if (($language -eq "LAD" -or $language -eq "FBD") -and $flgNets.Count -eq 0) {
            $issues.Add("No FlgNet elements found; file may not be LAD/FBD graph XML")
        }
        foreach ($part in $parts) {
            if (-not $part.Attributes["UId"]) {
                $issues.Add("Part without UId found")
                break
            }
        }
        foreach ($wire in $wires) {
            if (-not $wire.Attributes["UId"]) {
                $issues.Add("Wire without UId found")
                break
            }
        }
    }
    catch {
        $issues.Add("XML parse failed: $($_.Exception.Message)")
    }

    if ($schemaFiles | Where-Object { -not (Test-Path -LiteralPath $_) }) {
        $schemaStatus = "schema-files-missing"
    }
    else {
        $schemaStatus = "document-schema-skipped"
    }

    [pscustomobject]@{
        File = $file.FullName
        Ok = $issues.Count -eq 0
        SchemaStatus = $schemaStatus
        ProgrammingLanguage = $language
        CompileUnits = $compileUnitCount
        FlgNets = $flgNetCount
        Parts = $partCount
        Wires = $wireCount
        Issues = @($issues)
    }
}

$results | ConvertTo-Json -Depth 6
