param(
    [Parameter(Mandatory = $true)]
    [string]$TargetXml,

    [Parameter(Mandatory = $true)]
    [string]$SpecPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputXml,

    [Parameter(Mandatory = $true)]
    [int]$NetworkIndex
)

$ErrorActionPreference = "Stop"

function Get-XmlDocument {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "XML file not found: $Path" }
    $xml = New-Object System.Xml.XmlDocument
    $xml.PreserveWhitespace = $true
    $xml.Load((Get-Item -LiteralPath $Path).FullName)
    return $xml
}

function Select-CompileUnits {
    param([System.Xml.XmlNode]$Node)
    return @($Node.SelectNodes(".//*[local-name()='CompileUnit' or local-name()='SW.Blocks.CompileUnit']"))
}

function Get-InstancePathsFromDocument {
    param([System.Xml.XmlDocument]$Document)

    $paths = New-Object System.Collections.Generic.List[string]
    foreach ($instanceNode in @($Document.SelectNodes(".//*[local-name()='Instance']"))) {
        $components = @($instanceNode.SelectNodes("./*[local-name()='Component']"))
        if ($components.Count -eq 0) {
            continue
        }

        $names = foreach ($component in $components) {
            $component.GetAttribute("Name")
        }

        $paths.Add(($names -join "."))
    }

    return @($paths.ToArray())
}

function Get-NetworkUnit {
    param(
        [System.Xml.XmlNode[]]$Units,
        [int]$Index
    )
    if ($Index -lt 1) { throw "NetworkIndex must be greater than 0." }
    if ($Index -gt $Units.Count) { throw "NetworkIndex $Index exceeds network count $($Units.Count)." }
    return $Units[$Index - 1]
}

function New-FlgElement {
    param(
        [System.Xml.XmlDocument]$Document,
        [string]$Name
    )
    return $Document.CreateElement($Name, "http://www.siemens.com/automation/Openness/SW/NetworkSource/FlgNet/v4")
}

function Add-SymbolChild {
    param(
        [System.Xml.XmlDocument]$Document,
        [System.Xml.XmlElement]$Parent,
        [string]$Symbol = "",
        [object[]]$Components = @()
    )

    $symbolNode = New-FlgElement -Document $Document -Name "Symbol"
    $componentSpecs = @()
    if ($Components -and @($Components).Count -gt 0) {
        $componentSpecs = @($Components)
    }
    elseif ($Symbol) {
        $componentSpecs = @($Symbol.Split("."))
    }
    else {
        throw "Variable access requires symbol or components."
    }

    foreach ($componentSpec in $componentSpecs) {
        $componentName = ""
        $accessModifier = ""
        $nestedAccess = $null

        if ($componentSpec -is [string]) {
            $componentName = [string]$componentSpec
        }
        else {
            if (-not ($componentSpec.PSObject.Properties.Name -contains "name") -or -not $componentSpec.name) {
                throw "Each symbol component must provide name."
            }

            $componentName = [string]$componentSpec.name
            if ($componentSpec.PSObject.Properties.Name -contains "accessModifier" -and $componentSpec.accessModifier) {
                $accessModifier = [string]$componentSpec.accessModifier
            }

            if ($componentSpec.PSObject.Properties.Name -contains "index" -and $componentSpec.index) {
                $nestedAccess = $componentSpec.index
            }
            elseif ($componentSpec.PSObject.Properties.Name -contains "access" -and $componentSpec.access) {
                $nestedAccess = $componentSpec.access
            }
        }

        $component = New-FlgElement -Document $Document -Name "Component"
        $component.SetAttribute("Name", $componentName)
        if ($accessModifier) {
            $component.SetAttribute("AccessModifier", $accessModifier)
        }
        if ($nestedAccess) {
            Add-ComponentAccessChild -Document $Document -ComponentNode $component -AccessSpecInput $nestedAccess
        }
        $null = $symbolNode.AppendChild($component)
    }
    $null = $Parent.AppendChild($symbolNode)
}

function Add-ComponentAccessChild {
    param(
        [System.Xml.XmlDocument]$Document,
        [System.Xml.XmlElement]$ComponentNode,
        $AccessSpecInput
    )

    $resolvedAccess = Resolve-AccessSpec -Operand $AccessSpecInput -Role "component access" -ConditionKind "Symbol component"
    $accessNode = New-AccessNode -Document $Document -Scope $resolvedAccess.Scope -Uid 0 -Symbol $resolvedAccess.Symbol -Components $resolvedAccess.Components -ConstantValue $resolvedAccess.ConstantValue -ConstantType $resolvedAccess.ConstantType -ConstantName $resolvedAccess.ConstantName
    $accessNode.RemoveAttribute("UId")
    $null = $ComponentNode.AppendChild($accessNode)
}

function Reset-UidGenerator {
    $script:nextUid = 1000
}

function Get-NextUid {
    $script:nextUid += 1
    return [int]$script:nextUid
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

function Add-WireNode {
    param(
        [System.Xml.XmlDocument]$Document,
        [System.Xml.XmlElement]$WiresNode,
        [int]$WireUid,
        $FromIdentUid = $null,
        [int]$ToPartUid,
        [string]$ToName,
        [switch]$Powerrail
    )

    $wire = New-FlgElement -Document $Document -Name "Wire"
    $wire.SetAttribute("UId", [string]$WireUid)

    if ($Powerrail) {
        $null = $wire.AppendChild((New-FlgElement -Document $Document -Name "Powerrail"))
    }
    else {
        if ($null -eq $FromIdentUid) {
            throw "FromIdentUid is required when Powerrail is not used."
        }
        $identCon = New-FlgElement -Document $Document -Name "IdentCon"
        $identCon.SetAttribute("UId", [string]$FromIdentUid)
        $null = $wire.AppendChild($identCon)
    }

    $nameCon = New-FlgElement -Document $Document -Name "NameCon"
    $nameCon.SetAttribute("UId", [string]$ToPartUid)
    $nameCon.SetAttribute("Name", $ToName)
    $null = $wire.AppendChild($nameCon)
    $null = $WiresNode.AppendChild($wire)
}

function Add-PowerrailFanoutWire {
    param(
        [System.Xml.XmlDocument]$Document,
        [System.Xml.XmlElement]$WiresNode,
        [int]$WireUid,
        [int[]]$TargetPartUids,
        [string]$ToName
    )

    if ($TargetPartUids.Count -eq 0) {
        throw "TargetPartUids must contain at least one destination."
    }

    $wire = New-FlgElement -Document $Document -Name "Wire"
    $wire.SetAttribute("UId", [string]$WireUid)
    $null = $wire.AppendChild((New-FlgElement -Document $Document -Name "Powerrail"))

    foreach ($targetUid in $TargetPartUids) {
        $toNode = New-FlgElement -Document $Document -Name "NameCon"
        $toNode.SetAttribute("UId", [string]$targetUid)
        $toNode.SetAttribute("Name", $ToName)
        $null = $wire.AppendChild($toNode)
    }

    $null = $WiresNode.AppendChild($wire)
}

function Add-LinkWire {
    param(
        [System.Xml.XmlDocument]$Document,
        [System.Xml.XmlElement]$WiresNode,
        [int]$WireUid,
        [int]$FromPartUid,
        [string]$FromName,
        [int]$ToPartUid,
        [string]$ToName
    )

    $wire = New-FlgElement -Document $Document -Name "Wire"
    $wire.SetAttribute("UId", [string]$WireUid)

    $fromNode = New-FlgElement -Document $Document -Name "NameCon"
    $fromNode.SetAttribute("UId", [string]$FromPartUid)
    $fromNode.SetAttribute("Name", $FromName)
    $null = $wire.AppendChild($fromNode)

    $toNode = New-FlgElement -Document $Document -Name "NameCon"
    $toNode.SetAttribute("UId", [string]$ToPartUid)
    $toNode.SetAttribute("Name", $ToName)
    $null = $wire.AppendChild($toNode)

    $null = $WiresNode.AppendChild($wire)
}

function Add-FanoutWire {
    param(
        [System.Xml.XmlDocument]$Document,
        [System.Xml.XmlElement]$WiresNode,
        [int]$WireUid,
        [int]$FromPartUid,
        [string]$FromName,
        [int[]]$TargetPartUids,
        [string]$ToName
    )

    if ($TargetPartUids.Count -eq 0) {
        throw "TargetPartUids must contain at least one destination."
    }

    $wire = New-FlgElement -Document $Document -Name "Wire"
    $wire.SetAttribute("UId", [string]$WireUid)

    $fromNode = New-FlgElement -Document $Document -Name "NameCon"
    $fromNode.SetAttribute("UId", [string]$FromPartUid)
    $fromNode.SetAttribute("Name", $FromName)
    $null = $wire.AppendChild($fromNode)

    foreach ($targetUid in $TargetPartUids) {
        $toNode = New-FlgElement -Document $Document -Name "NameCon"
        $toNode.SetAttribute("UId", [string]$targetUid)
        $toNode.SetAttribute("Name", $ToName)
        $null = $wire.AppendChild($toNode)
    }

    $null = $WiresNode.AppendChild($wire)
}

function Add-MultiTargetLinkWire {
    param(
        [System.Xml.XmlDocument]$Document,
        [System.Xml.XmlElement]$WiresNode,
        [int]$WireUid,
        [int]$FromPartUid,
        [string]$FromName,
        [object[]]$Targets
    )

    if ($Targets.Count -eq 0) {
        throw "Targets must contain at least one destination."
    }

    $wire = New-FlgElement -Document $Document -Name "Wire"
    $wire.SetAttribute("UId", [string]$WireUid)

    $fromNode = New-FlgElement -Document $Document -Name "NameCon"
    $fromNode.SetAttribute("UId", [string]$FromPartUid)
    $fromNode.SetAttribute("Name", $FromName)
    $null = $wire.AppendChild($fromNode)

    foreach ($target in $Targets) {
        $toNode = New-FlgElement -Document $Document -Name "NameCon"
        $toNode.SetAttribute("UId", [string]$target.PartUid)
        $toNode.SetAttribute("Name", [string]$target.Name)
        $null = $wire.AppendChild($toNode)
    }

    $null = $WiresNode.AppendChild($wire)
}

function Add-PowerrailNamedTargetsWire {
    param(
        [System.Xml.XmlDocument]$Document,
        [System.Xml.XmlElement]$WiresNode,
        [int]$WireUid,
        [object[]]$Targets
    )

    if ($Targets.Count -eq 0) {
        throw "Targets must contain at least one destination."
    }

    $wire = New-FlgElement -Document $Document -Name "Wire"
    $wire.SetAttribute("UId", [string]$WireUid)
    $null = $wire.AppendChild((New-FlgElement -Document $Document -Name "Powerrail"))

    foreach ($target in $Targets) {
        $toNode = New-FlgElement -Document $Document -Name "NameCon"
        $toNode.SetAttribute("UId", [string]$target.PartUid)
        $toNode.SetAttribute("Name", [string]$target.Name)
        $null = $wire.AppendChild($toNode)
    }

    $null = $WiresNode.AppendChild($wire)
}

function Add-PartToIdentWire {
    param(
        [System.Xml.XmlDocument]$Document,
        [System.Xml.XmlElement]$WiresNode,
        [int]$WireUid,
        [int]$FromPartUid,
        [string]$FromName,
        [int]$ToIdentUid
    )

    $wire = New-FlgElement -Document $Document -Name "Wire"
    $wire.SetAttribute("UId", [string]$WireUid)

    $fromNode = New-FlgElement -Document $Document -Name "NameCon"
    $fromNode.SetAttribute("UId", [string]$FromPartUid)
    $fromNode.SetAttribute("Name", $FromName)
    $null = $wire.AppendChild($fromNode)

    $identNode = New-FlgElement -Document $Document -Name "IdentCon"
    $identNode.SetAttribute("UId", [string]$ToIdentUid)
    $null = $wire.AppendChild($identNode)

    $null = $WiresNode.AppendChild($wire)
}

function Add-OpenToPartWire {
    param(
        [System.Xml.XmlDocument]$Document,
        [System.Xml.XmlElement]$WiresNode,
        [int]$WireUid,
        [int]$ToPartUid,
        [string]$ToName
    )

    $wire = New-FlgElement -Document $Document -Name "Wire"
    $wire.SetAttribute("UId", [string]$WireUid)

    $openNode = New-FlgElement -Document $Document -Name "OpenCon"
    $openNode.SetAttribute("UId", [string](Get-NextUid))
    $null = $wire.AppendChild($openNode)

    $toNode = New-FlgElement -Document $Document -Name "NameCon"
    $toNode.SetAttribute("UId", [string]$ToPartUid)
    $toNode.SetAttribute("Name", $ToName)
    $null = $wire.AppendChild($toNode)

    $null = $WiresNode.AppendChild($wire)
}

function Add-PartToOpenWire {
    param(
        [System.Xml.XmlDocument]$Document,
        [System.Xml.XmlElement]$WiresNode,
        [int]$WireUid,
        [int]$FromPartUid,
        [string]$FromName
    )

    $wire = New-FlgElement -Document $Document -Name "Wire"
    $wire.SetAttribute("UId", [string]$WireUid)

    $fromNode = New-FlgElement -Document $Document -Name "NameCon"
    $fromNode.SetAttribute("UId", [string]$FromPartUid)
    $fromNode.SetAttribute("Name", $FromName)
    $null = $wire.AppendChild($fromNode)

    $openNode = New-FlgElement -Document $Document -Name "OpenCon"
    $openNode.SetAttribute("UId", [string](Get-NextUid))
    $null = $wire.AppendChild($openNode)

    $null = $WiresNode.AppendChild($wire)
}

function New-AccessNode {
    param(
        [System.Xml.XmlDocument]$Document,
        [string]$Scope,
        [int]$Uid,
        [string]$Symbol = "",
        [object[]]$Components = @(),
        [string]$ConstantValue = "",
        [string]$ConstantType = "",
        [string]$ConstantName = ""
    )

    $access = New-FlgElement -Document $Document -Name "Access"
    $access.SetAttribute("Scope", $Scope)
    $access.SetAttribute("UId", [string]$Uid)

    if ($Scope -eq "GlobalVariable" -or $Scope -eq "LocalVariable") {
        Add-SymbolChild -Document $Document -Parent $access -Symbol $Symbol -Components $Components
    }
    elseif ($Scope -eq "GlobalConstant" -and $ConstantName) {
        $constant = New-FlgElement -Document $Document -Name "Constant"
        $constant.SetAttribute("Name", $ConstantName)
        $null = $access.AppendChild($constant)
    }
    else {
        $constant = New-FlgElement -Document $Document -Name "Constant"
        if ($ConstantType) {
            $constantTypeNode = New-FlgElement -Document $Document -Name "ConstantType"
            $constantTypeNode.InnerText = $ConstantType
            $null = $constant.AppendChild($constantTypeNode)
        }
        $constantValueNode = New-FlgElement -Document $Document -Name "ConstantValue"
        $constantValueNode.InnerText = $ConstantValue
        $null = $constant.AppendChild($constantValueNode)
        $null = $access.AppendChild($constant)
    }

    return $access
}

function New-PartNode {
    param(
        [System.Xml.XmlDocument]$Document,
        [string]$Name,
        [int]$Uid
    )

    $part = New-FlgElement -Document $Document -Name "Part"
    $part.SetAttribute("Name", $Name)
    $part.SetAttribute("UId", [string]$Uid)
    return $part
}

function Add-TemplateValueNode {
    param(
        [System.Xml.XmlDocument]$Document,
        [System.Xml.XmlElement]$Parent,
        [string]$Name,
        [string]$Type,
        [string]$Value
    )

    $template = New-FlgElement -Document $Document -Name "TemplateValue"
    $template.SetAttribute("Name", $Name)
    $template.SetAttribute("Type", $Type)
    $template.InnerText = $Value
    $null = $Parent.AppendChild($template)
}

function Resolve-AccessSpec {
    param(
        $Operand,
        [string]$Role,
        [string]$ConditionKind
    )

    if (-not $Operand) {
        throw "$ConditionKind condition requires a $Role operand."
    }

    if ($Operand.PSObject.Properties.Name -contains "components" -and $Operand.components -and @($Operand.components).Count -gt 0) {
        $scope = "GlobalVariable"
        if ($Operand.PSObject.Properties.Name -contains "scope" -and $Operand.scope) {
            $scope = [string]$Operand.scope
        }

        return [pscustomobject]@{
            Scope = $scope
            Symbol = ""
            Components = @($Operand.components)
            ConstantValue = ""
            ConstantType = ""
            ConstantName = ""
        }
    }

    if ($Operand.PSObject.Properties.Name -contains "symbol" -and $Operand.symbol) {
        $scope = "GlobalVariable"
        if ($Operand.PSObject.Properties.Name -contains "scope" -and $Operand.scope) {
            $scope = [string]$Operand.scope
        }

        return [pscustomobject]@{
            Scope = $scope
            Symbol = [string]$Operand.symbol
            Components = @()
            ConstantValue = ""
            ConstantType = ""
            ConstantName = ""
        }
    }

    if ($Operand.PSObject.Properties.Name -contains "constantName" -and $Operand.constantName) {
        $scope = "GlobalConstant"
        if ($Operand.PSObject.Properties.Name -contains "scope" -and $Operand.scope) {
            $scope = [string]$Operand.scope
        }

        return [pscustomobject]@{
            Scope = $scope
            Symbol = ""
            Components = @()
            ConstantValue = ""
            ConstantType = ""
            ConstantName = [string]$Operand.constantName
        }
    }

    if ($Operand.PSObject.Properties.Name -contains "value") {
        $scope = "LiteralConstant"
        if ($Operand.PSObject.Properties.Name -contains "scope" -and $Operand.scope) {
            $scope = [string]$Operand.scope
        }

        $constantType = ""
        if ($Operand.PSObject.Properties.Name -contains "constantType" -and $Operand.constantType) {
            $constantType = [string]$Operand.constantType
        }

        return [pscustomobject]@{
            Scope = $scope
            Symbol = ""
            Components = @()
            ConstantValue = [string]$Operand.value
            ConstantType = $constantType
            ConstantName = ""
        }
    }

    throw "$ConditionKind condition requires $Role to provide symbol, components, constantName, or value."
}

function Resolve-TargetSpec {
    param(
        $Target,
        [string]$ActionKind
    )

    if ($Target -is [string]) {
        return [pscustomobject]@{
            Scope = "GlobalVariable"
            Symbol = [string]$Target
            Components = @()
        }
    }

    if (-not $Target) {
        throw "$ActionKind action requires target."
    }

    if ($Target.PSObject.Properties.Name -contains "components" -and $Target.components -and @($Target.components).Count -gt 0) {
        $scope = "GlobalVariable"
        if ($Target.PSObject.Properties.Name -contains "scope" -and $Target.scope) {
            $scope = [string]$Target.scope
        }

        return [pscustomobject]@{
            Scope = $scope
            Symbol = ""
            Components = @($Target.components)
        }
    }

    if (-not ($Target.PSObject.Properties.Name -contains "symbol") -or -not $Target.symbol) {
        throw "$ActionKind action target requires symbol or components."
    }

    $scope = "GlobalVariable"
    if ($Target.PSObject.Properties.Name -contains "scope" -and $Target.scope) {
        $scope = [string]$Target.scope
    }

    return [pscustomobject]@{
        Scope = $scope
        Symbol = [string]$Target.symbol
        Components = @()
    }
}

function Get-ConditionGroupsFromContainer {
    param(
        $Container,
        [string]$GroupsProperty = "conditionGroups",
        [string]$ConditionsProperty = "conditions",
        [string]$Label = "Spec",
        [switch]$AllowEmpty
    )

    if ($Container.PSObject.Properties.Name -contains $GroupsProperty -and $Container.$GroupsProperty -and @($Container.$GroupsProperty).Count -gt 0) {
        return @($Container.$GroupsProperty)
    }

    if ($Container.PSObject.Properties.Name -contains $ConditionsProperty -and $Container.$ConditionsProperty -and @($Container.$ConditionsProperty).Count -gt 0) {
        return @([pscustomobject]@{
            conditions = @($Container.$ConditionsProperty)
        })
    }

    if ($AllowEmpty) {
        return @()
    }

    throw "$Label must contain at least one $ConditionsProperty or $GroupsProperty entry."
}

function Add-ConditionPartFromSpec {
    param(
        [System.Xml.XmlDocument]$Document,
        [System.Xml.XmlElement]$PartsNode,
        [System.Xml.XmlElement]$WiresNode,
        $Condition
    )

    if (-not $Condition.kind) {
        throw "Each condition must contain kind."
    }

    $conditionKind = [string]$Condition.kind
    $partUid = $null
    $signalInputName = "in"

    switch ($conditionKind) {
        { $_ -in @("NO", "NC") } {
            if (-not $Condition.symbol) {
                throw "$conditionKind condition requires symbol."
            }

            $conditionScope = "GlobalVariable"
            if ($Condition.PSObject.Properties.Name -contains "scope" -and $Condition.scope) {
                $conditionScope = [string]$Condition.scope
            }

            $accessUid = Get-NextUid
            $access = New-AccessNode -Document $Document -Scope $conditionScope -Uid $accessUid -Symbol ([string]$Condition.symbol)
            $null = $PartsNode.AppendChild($access)

            $partUid = Get-NextUid
            $part = New-PartNode -Document $Document -Name "Contact" -Uid $partUid
            if ($conditionKind -eq "NC") {
                $negated = New-FlgElement -Document $Document -Name "Negated"
                $negated.SetAttribute("Name", "operand")
                $null = $part.AppendChild($negated)
            }
            $null = $PartsNode.AppendChild($part)

            Add-WireNode -Document $Document -WiresNode $WiresNode -WireUid (Get-NextUid) -FromIdentUid $accessUid -ToPartUid $partUid -ToName "operand"
        }
        { $_ -in @("P_EDGE", "N_EDGE") } {
            if (-not $Condition.symbol) {
                throw "$conditionKind condition requires symbol."
            }

            $operandScope = "GlobalVariable"
            if ($Condition.PSObject.Properties.Name -contains "scope" -and $Condition.scope) {
                $operandScope = [string]$Condition.scope
            }

            $bitTarget = $null
            if ($Condition.PSObject.Properties.Name -contains "bit" -and $Condition.bit) {
                $bitTarget = $Condition.bit
            }
            elseif ($Condition.PSObject.Properties.Name -contains "bitSymbol" -and $Condition.bitSymbol) {
                $bitTarget = [pscustomobject]@{
                    symbol = [string]$Condition.bitSymbol
                    scope = if ($Condition.PSObject.Properties.Name -contains "bitScope" -and $Condition.bitScope) { [string]$Condition.bitScope } else { "GlobalVariable" }
                }
            }

            if (-not $bitTarget) {
                throw "$conditionKind condition requires bit or bitSymbol."
            }

            $bitSpec = Resolve-TargetSpec -Target $bitTarget -ActionKind $conditionKind

            $operandAccessUid = Get-NextUid
            $operandAccess = New-AccessNode -Document $Document -Scope $operandScope -Uid $operandAccessUid -Symbol ([string]$Condition.symbol)
            $null = $PartsNode.AppendChild($operandAccess)

            $bitAccessUid = Get-NextUid
            $bitAccess = New-AccessNode -Document $Document -Scope $bitSpec.Scope -Uid $bitAccessUid -Symbol $bitSpec.Symbol -Components $bitSpec.Components
            $null = $PartsNode.AppendChild($bitAccess)

            $partName = if ($conditionKind -eq "P_EDGE") { "PContact" } else { "NContact" }
            $partUid = Get-NextUid
            $part = New-PartNode -Document $Document -Name $partName -Uid $partUid
            $null = $PartsNode.AppendChild($part)

            Add-WireNode -Document $Document -WiresNode $WiresNode -WireUid (Get-NextUid) -FromIdentUid $operandAccessUid -ToPartUid $partUid -ToName "operand"
            Add-WireNode -Document $Document -WiresNode $WiresNode -WireUid (Get-NextUid) -FromIdentUid $bitAccessUid -ToPartUid $partUid -ToName "bit"

            $signalInputName = "pre"
        }
        { $_ -in @("EQ", "NE", "GE", "GT", "LE", "LT") } {
            if (-not $Condition.sourceType) {
                throw "$conditionKind condition requires sourceType."
            }
            if (-not $Condition.left -or -not $Condition.right) {
                throw "$conditionKind condition requires left and right operands."
            }

            $leftSpec = Resolve-AccessSpec -Operand $Condition.left -Role "left" -ConditionKind $conditionKind
            $rightSpec = Resolve-AccessSpec -Operand $Condition.right -Role "right" -ConditionKind $conditionKind

            $leftAccessUid = Get-NextUid
            $leftAccess = New-AccessNode -Document $Document -Scope $leftSpec.Scope -Uid $leftAccessUid -Symbol $leftSpec.Symbol -Components $leftSpec.Components -ConstantValue $leftSpec.ConstantValue -ConstantType $leftSpec.ConstantType
            $null = $PartsNode.AppendChild($leftAccess)

            $rightAccessUid = Get-NextUid
            $rightAccess = New-AccessNode -Document $Document -Scope $rightSpec.Scope -Uid $rightAccessUid -Symbol $rightSpec.Symbol -Components $rightSpec.Components -ConstantValue $rightSpec.ConstantValue -ConstantType $rightSpec.ConstantType
            $null = $PartsNode.AppendChild($rightAccess)

            $comparePartName = switch ($conditionKind) {
                "EQ" { "Eq" }
                "NE" { "Ne" }
                "GE" { "Ge" }
                "GT" { "Gt" }
                "LE" { "Le" }
                "LT" { "Lt" }
            }

            $partUid = Get-NextUid
            $part = New-PartNode -Document $Document -Name $comparePartName -Uid $partUid
            Add-TemplateValueNode -Document $Document -Parent $part -Name "SrcType" -Type "Type" -Value ([string]$Condition.sourceType)
            $null = $PartsNode.AppendChild($part)

            Add-WireNode -Document $Document -WiresNode $WiresNode -WireUid (Get-NextUid) -FromIdentUid $leftAccessUid -ToPartUid $partUid -ToName "in1"
            Add-WireNode -Document $Document -WiresNode $WiresNode -WireUid (Get-NextUid) -FromIdentUid $rightAccessUid -ToPartUid $partUid -ToName "in2"

            $signalInputName = "pre"
        }
        default {
            throw "Unsupported condition kind '$conditionKind'. Supported: NO, NC, P_EDGE, N_EDGE, EQ, NE, GE, GT, LE, LT."
        }
    }

    return [pscustomobject]@{
        PartUid = [int]$partUid
        SignalInputName = $signalInputName
    }
}

function Build-SignalPathFromConditionGroups {
    param(
        [System.Xml.XmlDocument]$Document,
        [System.Xml.XmlElement]$PartsNode,
        [System.Xml.XmlElement]$WiresNode,
        [object[]]$ConditionGroups,
        [System.Collections.Generic.List[object]]$RootTargets,
        $UpstreamSignalPartUid = $null,
        [string]$UpstreamSignalName = $null,
        [switch]$SkipSourceConnection
    )

    $groupStates = New-Object System.Collections.Generic.List[object]

    foreach ($group in $ConditionGroups) {
        $groupConditions = @($group.conditions)
        if ($groupConditions.Count -eq 0) {
            throw "Each condition group must contain at least one condition."
        }

        $groupParts = New-Object System.Collections.Generic.List[object]
        foreach ($condition in $groupConditions) {
            $groupParts.Add((Add-ConditionPartFromSpec -Document $Document -PartsNode $PartsNode -WiresNode $WiresNode -Condition $condition))
        }

        for ($i = 0; $i -lt $groupParts.Count - 1; $i++) {
            Add-LinkWire -Document $Document -WiresNode $WiresNode -WireUid (Get-NextUid) -FromPartUid $groupParts[$i].PartUid -FromName "out" -ToPartUid $groupParts[$i + 1].PartUid -ToName $groupParts[$i + 1].SignalInputName
        }

        $groupStates.Add([pscustomobject]@{
            FirstPartUid = $groupParts[0].PartUid
            FirstSignalInputName = $groupParts[0].SignalInputName
            LastPartUid = $groupParts[$groupParts.Count - 1].PartUid
        })
    }

    $signalSourcePartUid = $null
    $signalSourceName = "out"
    $branchTargets = New-Object System.Collections.Generic.List[object]

    foreach ($groupState in $groupStates) {
        $branchTargets.Add([pscustomobject]@{
            PartUid = $groupState.FirstPartUid
            Name = $groupState.FirstSignalInputName
        })
    }

    $hasUpstreamSignal = $false
    if ($null -ne $UpstreamSignalPartUid -and -not [string]::IsNullOrWhiteSpace([string]$UpstreamSignalPartUid)) {
        $hasUpstreamSignal = $true
        Assert-SignalPathAvailable -SignalSourcePartUid $UpstreamSignalPartUid -Context "Condition branch"
        if ([string]::IsNullOrWhiteSpace($UpstreamSignalName)) {
            $UpstreamSignalName = "out"
        }
    }

    if (-not $SkipSourceConnection) {
        if ($hasUpstreamSignal) {
            Add-MultiTargetLinkWire -Document $Document -WiresNode $WiresNode -WireUid (Get-NextUid) -FromPartUid ([int]$UpstreamSignalPartUid) -FromName $UpstreamSignalName -Targets @($branchTargets.ToArray())
        }
        else {
            foreach ($branchTarget in @($branchTargets.ToArray())) {
                $RootTargets.Add($branchTarget)
            }
        }
    }

    if ($groupStates.Count -eq 1) {
        $signalSourcePartUid = $groupStates[0].LastPartUid
    }
    else {
        $orPartUid = Get-NextUid
        $orPart = New-PartNode -Document $Document -Name "O" -Uid $orPartUid
        Add-TemplateValueNode -Document $Document -Parent $orPart -Name "Card" -Type "Cardinality" -Value ([string]$groupStates.Count)
        $null = $PartsNode.AppendChild($orPart)

        for ($groupIndex = 0; $groupIndex -lt $groupStates.Count; $groupIndex++) {
            Add-LinkWire -Document $Document -WiresNode $WiresNode -WireUid (Get-NextUid) -FromPartUid $groupStates[$groupIndex].LastPartUid -FromName "out" -ToPartUid $orPartUid -ToName ("in{0}" -f ($groupIndex + 1))
        }

        $signalSourcePartUid = $orPartUid
    }

    return [pscustomobject]@{
        SignalSourcePartUid = $signalSourcePartUid
        SignalSourceName = $signalSourceName
        GroupCount = $groupStates.Count
        EntryTargets = @($branchTargets.ToArray())
    }
}

function Get-ConditionGroupsFromSpec {
    param(
        [pscustomobject]$Spec,
        [switch]$AllowEmpty
    )

    return @(Get-ConditionGroupsFromContainer -Container $Spec -GroupsProperty "conditionGroups" -ConditionsProperty "conditions" -Label "Spec" -AllowEmpty:$AllowEmpty)
}

function Get-BranchesFromSpec {
    param([pscustomobject]$Spec)

    if ($Spec.PSObject.Properties.Name -contains "branches" -and $Spec.branches) {
        return @($Spec.branches)
    }

    return @()
}

function Resolve-ActionSignalSource {
    param(
        $Action,
        [object[]]$ActionPartRefs,
        [string]$ActionKind,
        $DefaultPartUid,
        [string]$DefaultName
    )

    $resolvedPartUid = $DefaultPartUid
    $resolvedName = $DefaultName

    if ($Action.PSObject.Properties.Name -contains "signalSource" -and $Action.signalSource) {
        $signalSourceSpec = $Action.signalSource
        if (-not ($signalSourceSpec.PSObject.Properties.Name -contains "actionIndex") -or -not $signalSourceSpec.actionIndex) {
            throw "$ActionKind signalSource requires actionIndex."
        }

        $sourceActionIndex = [int]$signalSourceSpec.actionIndex
        $matchingRef = @($ActionPartRefs | Where-Object { $_.ActionIndex -eq $sourceActionIndex } | Select-Object -First 1)[0]
        if (-not $matchingRef) {
            throw "$ActionKind signalSource actionIndex $sourceActionIndex does not match a previously emitted action part."
        }

        $resolvedPartUid = [int]$matchingRef.PartUid
        if ($signalSourceSpec.PSObject.Properties.Name -contains "name" -and $signalSourceSpec.name) {
            $resolvedName = [string]$signalSourceSpec.name
        }
        elseif ($matchingRef.PSObject.Properties.Name -contains "DefaultSignalName" -and $matchingRef.DefaultSignalName) {
            $resolvedName = [string]$matchingRef.DefaultSignalName
        }
        else {
            $resolvedName = "out"
        }
    }

    return [pscustomobject]@{
        PartUid = $resolvedPartUid
        Name = $resolvedName
    }
}

function Assert-SignalPathAvailable {
    param(
        $SignalSourcePartUid,
        [string]$Context
    )

    if ($null -eq $SignalSourcePartUid -or [string]::IsNullOrWhiteSpace([string]$SignalSourcePartUid)) {
        throw "$Context requires at least one condition path."
    }
}

function Emit-ActionsFromList {
    param(
        [System.Xml.XmlDocument]$Document,
        [System.Xml.XmlElement]$PartsNode,
        [System.Xml.XmlElement]$WiresNode,
        [object[]]$Actions,
        [System.Collections.Generic.List[object]]$RootTargets,
        $SignalSourcePartUid,
        [string]$SignalSourceName,
        [System.Collections.Generic.List[object]]$ActionPartRefs,
        [ref]$CurrentActionIndexRef,
        [switch]$DeferTerminalPendingOutputs
    )

    if (-not $Actions -or @($Actions).Count -eq 0) {
        return [pscustomobject]@{
            FinalSignalSourcePartUid = $SignalSourcePartUid
            FinalSignalSourceName = $SignalSourceName
            DeferredTerminalTargets = @()
        }
    }

    $pendingActionPartUids = New-Object System.Collections.Generic.List[int]

    foreach ($action in @($Actions)) {
        $CurrentActionIndexRef.Value += 1
        $currentActionIndex = [int]$CurrentActionIndexRef.Value
        if (-not $action.kind) {
            throw "Each action must contain kind."
        }

        $kind = [string]$action.kind
        switch ($kind) {
            "COIL" {
                if (-not $action.symbol) { throw "COIL action requires symbol." }
                $actionScope = "GlobalVariable"
                if ($action.PSObject.Properties.Name -contains "scope" -and $action.scope) {
                    $actionScope = [string]$action.scope
                }
                $accessUid = Get-NextUid
                $access = New-AccessNode -Document $Document -Scope $actionScope -Uid $accessUid -Symbol ([string]$action.symbol)
                $null = $partsNode.AppendChild($access)

                $partUid = Get-NextUid
                $part = New-PartNode -Document $Document -Name "Coil" -Uid $partUid
                $null = $partsNode.AppendChild($part)
                Add-WireNode -Document $Document -WiresNode $wiresNode -WireUid (Get-NextUid) -FromIdentUid $accessUid -ToPartUid $partUid -ToName "operand"
                $pendingActionPartUids.Add($partUid)
            }
            "SET" {
                if (-not $action.symbol) { throw "SET action requires symbol." }
                $actionScope = "GlobalVariable"
                if ($action.PSObject.Properties.Name -contains "scope" -and $action.scope) {
                    $actionScope = [string]$action.scope
                }
                $accessUid = Get-NextUid
                $access = New-AccessNode -Document $Document -Scope $actionScope -Uid $accessUid -Symbol ([string]$action.symbol)
                $null = $partsNode.AppendChild($access)

                $partUid = Get-NextUid
                $part = New-PartNode -Document $Document -Name "SCoil" -Uid $partUid
                $null = $partsNode.AppendChild($part)
                Add-WireNode -Document $Document -WiresNode $wiresNode -WireUid (Get-NextUid) -FromIdentUid $accessUid -ToPartUid $partUid -ToName "operand"
                $pendingActionPartUids.Add($partUid)
            }
            "RESET" {
                if (-not $action.symbol) { throw "RESET action requires symbol." }
                $actionScope = "GlobalVariable"
                if ($action.PSObject.Properties.Name -contains "scope" -and $action.scope) {
                    $actionScope = [string]$action.scope
                }
                $accessUid = Get-NextUid
                $access = New-AccessNode -Document $Document -Scope $actionScope -Uid $accessUid -Symbol ([string]$action.symbol)
                $null = $partsNode.AppendChild($access)

                $partUid = Get-NextUid
                $part = New-PartNode -Document $Document -Name "RCoil" -Uid $partUid
                $null = $partsNode.AppendChild($part)
                Add-WireNode -Document $Document -WiresNode $wiresNode -WireUid (Get-NextUid) -FromIdentUid $accessUid -ToPartUid $partUid -ToName "operand"
                $pendingActionPartUids.Add($partUid)
            }
            { $_ -in @("TON", "TOF", "TP") } {
                $timerKind = $kind
                Assert-SignalPathAvailable -SignalSourcePartUid $signalSourcePartUid -Context "$timerKind action"
                if ($pendingActionPartUids.Count -gt 0) {
                    Add-FanoutWire -Document $Document -WiresNode $wiresNode -WireUid (Get-NextUid) -FromPartUid $signalSourcePartUid -FromName $signalSourceName -TargetPartUids @($pendingActionPartUids.ToArray()) -ToName "in"
                    $pendingActionPartUids.Clear()
                }
                if (-not $action.instance) { throw "$timerKind action requires instance." }
                if (-not $action.pt) { throw "$timerKind action requires pt." }

                $ptAccessUid = Get-NextUid
                if ($action.pt -is [string]) {
                    $ptAccess = New-AccessNode -Document $Document -Scope "TypedConstant" -Uid $ptAccessUid -ConstantValue ([string]$action.pt)
                }
                else {
                    $ptSpec = Resolve-AccessSpec -Operand $action.pt -Role "pt" -ConditionKind $timerKind
                    $ptScope = [string]$ptSpec.Scope
                    $ptConstantType = [string]$ptSpec.ConstantType

                    if (-not $ptSpec.Symbol -and @($ptSpec.Components).Count -eq 0 -and -not $ptSpec.ConstantName) {
                        if ([string]::IsNullOrWhiteSpace($ptScope) -or $ptScope -eq "LiteralConstant" -or $ptScope -eq "TypedConstant") {
                            $ptScope = "TypedConstant"
                            $ptConstantType = ""
                        }
                    }

                    $ptAccess = New-AccessNode -Document $Document -Scope $ptScope -Uid $ptAccessUid -Symbol $ptSpec.Symbol -Components $ptSpec.Components -ConstantValue $ptSpec.ConstantValue -ConstantType $ptConstantType -ConstantName $ptSpec.ConstantName
                }
                $null = $partsNode.AppendChild($ptAccess)

                $timerPartUid = Get-NextUid
                $timerPart = New-PartNode -Document $Document -Name $timerKind -Uid $timerPartUid
                $timerPart.SetAttribute("Version", "1.0")
                $instanceNode = New-FlgElement -Document $Document -Name "Instance"
                $instanceNode.SetAttribute("Scope", "GlobalVariable")
                $instanceNode.SetAttribute("UId", [string](Get-NextUid))
                foreach ($componentName in ([string]$action.instance).Split(".")) {
                    $component = New-FlgElement -Document $Document -Name "Component"
                    $component.SetAttribute("Name", $componentName)
                    $null = $instanceNode.AppendChild($component)
                }
                $null = $timerPart.AppendChild($instanceNode)
                Add-TemplateValueNode -Document $Document -Parent $timerPart -Name "time_type" -Type "Type" -Value "Time"
                $null = $partsNode.AppendChild($timerPart)
                $actionPartRefs.Add([pscustomobject]@{
                    ActionIndex = $currentActionIndex
                    Kind = $timerKind
                    PartUid = $timerPartUid
                    DefaultSignalName = "Q"
                })

                Add-LinkWire -Document $Document -WiresNode $wiresNode -WireUid (Get-NextUid) -FromPartUid $signalSourcePartUid -FromName $signalSourceName -ToPartUid $timerPartUid -ToName "IN"
                Add-WireNode -Document $Document -WiresNode $wiresNode -WireUid (Get-NextUid) -FromIdentUid $ptAccessUid -ToPartUid $timerPartUid -ToName "PT"

                $openCon = New-FlgElement -Document $Document -Name "OpenCon"
                $openCon.SetAttribute("UId", [string](Get-NextUid))
                $wireEt = New-FlgElement -Document $Document -Name "Wire"
                $wireEt.SetAttribute("UId", [string](Get-NextUid))
                $fromEt = New-FlgElement -Document $Document -Name "NameCon"
                $fromEt.SetAttribute("UId", [string]$timerPartUid)
                $fromEt.SetAttribute("Name", "ET")
                $null = $wireEt.AppendChild($fromEt)
                $null = $wireEt.AppendChild($openCon)
                $null = $wiresNode.AppendChild($wireEt)

                $signalSourcePartUid = $timerPartUid
                $signalSourceName = "Q"
            }
            "MOVE" {
                if (-not ($action.PSObject.Properties.Name -contains "source")) {
                    throw "MOVE action requires source."
                }
                if (-not ($action.PSObject.Properties.Name -contains "target")) {
                    throw "MOVE action requires target."
                }

                $sourceSpec = Resolve-AccessSpec -Operand $action.source -Role "source" -ConditionKind "MOVE"
                $targetSpec = Resolve-TargetSpec -Target $action.target -ActionKind "MOVE"

                $sourceAccessUid = Get-NextUid
                $sourceAccess = New-AccessNode -Document $Document -Scope $sourceSpec.Scope -Uid $sourceAccessUid -Symbol $sourceSpec.Symbol -Components $sourceSpec.Components -ConstantValue $sourceSpec.ConstantValue -ConstantType $sourceSpec.ConstantType
                $null = $partsNode.AppendChild($sourceAccess)

                $targetAccessUid = Get-NextUid
                $targetAccess = New-AccessNode -Document $Document -Scope $targetSpec.Scope -Uid $targetAccessUid -Symbol $targetSpec.Symbol -Components $targetSpec.Components
                $null = $partsNode.AppendChild($targetAccess)

                $movePartUid = Get-NextUid
                $movePart = New-PartNode -Document $Document -Name "Move" -Uid $movePartUid
                $movePart.SetAttribute("DisabledENO", "true")
                Add-TemplateValueNode -Document $Document -Parent $movePart -Name "Card" -Type "Cardinality" -Value "1"
                $null = $partsNode.AppendChild($movePart)
                $actionPartRefs.Add([pscustomobject]@{
                    ActionIndex = $currentActionIndex
                    Kind = "MOVE"
                    PartUid = $movePartUid
                    DefaultSignalName = "eno"
                })

                $moveUsesPowerRail = $false
                if ($action.PSObject.Properties.Name -contains "powerRail" -and $action.powerRail) {
                    $moveUsesPowerRail = $true
                    $rootTargets.Add([pscustomobject]@{
                        PartUid = $movePartUid
                        Name = "en"
                    })
                }

                if ($moveUsesPowerRail -and $action.PSObject.Properties.Name -contains "signalSource" -and $action.signalSource) {
                    throw "MOVE action cannot combine powerRail=true with signalSource."
                }

                $moveSignalSource = Resolve-ActionSignalSource -Action $action -ActionPartRefs @($actionPartRefs.ToArray()) -ActionKind "MOVE action" -DefaultPartUid $signalSourcePartUid -DefaultName $signalSourceName

                if ($pendingActionPartUids.Count -gt 0) {
                    $targets = New-Object System.Collections.Generic.List[object]
                    foreach ($pendingPartUid in @($pendingActionPartUids.ToArray())) {
                        $targets.Add([pscustomobject]@{
                            PartUid = [int]$pendingPartUid
                            Name = "in"
                        })
                    }
                    if (-not $moveUsesPowerRail) {
                        Assert-SignalPathAvailable -SignalSourcePartUid $moveSignalSource.PartUid -Context "MOVE action"
                        $targets.Add([pscustomobject]@{
                            PartUid = $movePartUid
                            Name = "en"
                        })
                    }
                    Add-MultiTargetLinkWire -Document $Document -WiresNode $wiresNode -WireUid (Get-NextUid) -FromPartUid $moveSignalSource.PartUid -FromName $moveSignalSource.Name -Targets @($targets.ToArray())
                    $pendingActionPartUids.Clear()
                }
                elseif (-not $moveUsesPowerRail) {
                    Assert-SignalPathAvailable -SignalSourcePartUid $moveSignalSource.PartUid -Context "MOVE action"
                    Add-LinkWire -Document $Document -WiresNode $wiresNode -WireUid (Get-NextUid) -FromPartUid $moveSignalSource.PartUid -FromName $moveSignalSource.Name -ToPartUid $movePartUid -ToName "en"
                }
                Add-WireNode -Document $Document -WiresNode $wiresNode -WireUid (Get-NextUid) -FromIdentUid $sourceAccessUid -ToPartUid $movePartUid -ToName "in"
                Add-PartToIdentWire -Document $Document -WiresNode $wiresNode -WireUid (Get-NextUid) -FromPartUid $movePartUid -FromName "out1" -ToIdentUid $targetAccessUid
            }
            { $_ -in @("CTU", "CTD", "CTUD") } {
                $counterKind = $kind
                Assert-SignalPathAvailable -SignalSourcePartUid $signalSourcePartUid -Context "$counterKind action"
                if ($pendingActionPartUids.Count -gt 0) {
                    Add-FanoutWire -Document $Document -WiresNode $wiresNode -WireUid (Get-NextUid) -FromPartUid $signalSourcePartUid -FromName $signalSourceName -TargetPartUids @($pendingActionPartUids.ToArray()) -ToName "in"
                    $pendingActionPartUids.Clear()
                }

                if (-not $action.instance) { throw "$counterKind action requires instance." }
                if (-not $action.valueType) { throw "$counterKind action requires valueType." }
                if (-not ($action.PSObject.Properties.Name -contains "pv")) { throw "$counterKind action requires pv." }

                $pvSpec = Resolve-AccessSpec -Operand $action.pv -Role "pv" -ConditionKind $counterKind
                $pvAccessUid = Get-NextUid
                $pvAccess = New-AccessNode -Document $Document -Scope $pvSpec.Scope -Uid $pvAccessUid -Symbol $pvSpec.Symbol -Components $pvSpec.Components -ConstantValue $pvSpec.ConstantValue -ConstantType $pvSpec.ConstantType
                $null = $partsNode.AppendChild($pvAccess)

                $counterPartUid = Get-NextUid
                $counterPart = New-PartNode -Document $Document -Name $counterKind -Uid $counterPartUid
                $counterPart.SetAttribute("Version", "1.0")
                $instanceNode = New-FlgElement -Document $Document -Name "Instance"
                $instanceNode.SetAttribute("Scope", "GlobalVariable")
                $instanceNode.SetAttribute("UId", [string](Get-NextUid))
                foreach ($componentName in ([string]$action.instance).Split(".")) {
                    $component = New-FlgElement -Document $Document -Name "Component"
                    $component.SetAttribute("Name", $componentName)
                    $null = $instanceNode.AppendChild($component)
                }
                $null = $counterPart.AppendChild($instanceNode)
                Add-TemplateValueNode -Document $Document -Parent $counterPart -Name "value_type" -Type "Type" -Value ([string]$action.valueType)
                $null = $partsNode.AppendChild($counterPart)
                $actionPartRefs.Add([pscustomobject]@{
                    ActionIndex = $currentActionIndex
                    Kind = $counterKind
                    PartUid = $counterPartUid
                    DefaultSignalName = if ($counterKind -eq "CTUD") { "QU" } else { "Q" }
                })

                $primaryInputName = switch ($counterKind) {
                    "CTU" { "CU" }
                    "CTD" { "CD" }
                    "CTUD" { "CU" }
                }
                Add-LinkWire -Document $Document -WiresNode $wiresNode -WireUid (Get-NextUid) -FromPartUid $signalSourcePartUid -FromName $signalSourceName -ToPartUid $counterPartUid -ToName $primaryInputName

                $hasResetGroups = $false
                if (($action.PSObject.Properties.Name -contains "resetConditionGroups" -and $action.resetConditionGroups) -or ($action.PSObject.Properties.Name -contains "resetConditions" -and $action.resetConditions)) {
                    $hasResetGroups = $true
                }
                if ($hasResetGroups -and $counterKind -in @("CTU", "CTUD")) {
                    $resetGroups = @(Get-ConditionGroupsFromContainer -Container $action -GroupsProperty "resetConditionGroups" -ConditionsProperty "resetConditions" -Label "$counterKind action")
                    $resetSignal = Build-SignalPathFromConditionGroups -Document $Document -PartsNode $partsNode -WiresNode $wiresNode -ConditionGroups $resetGroups -RootTargets $rootTargets
                    Add-LinkWire -Document $Document -WiresNode $wiresNode -WireUid (Get-NextUid) -FromPartUid $resetSignal.SignalSourcePartUid -FromName $resetSignal.SignalSourceName -ToPartUid $counterPartUid -ToName "R"
                }

                $hasLoadGroups = $false
                if (($action.PSObject.Properties.Name -contains "loadConditionGroups" -and $action.loadConditionGroups) -or ($action.PSObject.Properties.Name -contains "loadConditions" -and $action.loadConditions)) {
                    $hasLoadGroups = $true
                }
                if ($hasLoadGroups -and $counterKind -in @("CTD", "CTUD")) {
                    $loadGroups = @(Get-ConditionGroupsFromContainer -Container $action -GroupsProperty "loadConditionGroups" -ConditionsProperty "loadConditions" -Label "$counterKind action")
                    $loadSignal = Build-SignalPathFromConditionGroups -Document $Document -PartsNode $partsNode -WiresNode $wiresNode -ConditionGroups $loadGroups -RootTargets $rootTargets
                    Add-LinkWire -Document $Document -WiresNode $wiresNode -WireUid (Get-NextUid) -FromPartUid $loadSignal.SignalSourcePartUid -FromName $loadSignal.SignalSourceName -ToPartUid $counterPartUid -ToName "LD"
                }

                $hasDownGroups = $false
                if (($action.PSObject.Properties.Name -contains "downConditionGroups" -and $action.downConditionGroups) -or ($action.PSObject.Properties.Name -contains "downConditions" -and $action.downConditions)) {
                    $hasDownGroups = $true
                }
                if ($hasDownGroups -and $counterKind -eq "CTUD") {
                    $downGroups = @(Get-ConditionGroupsFromContainer -Container $action -GroupsProperty "downConditionGroups" -ConditionsProperty "downConditions" -Label "CTUD action")
                    $downSignal = Build-SignalPathFromConditionGroups -Document $Document -PartsNode $partsNode -WiresNode $wiresNode -ConditionGroups $downGroups -RootTargets $rootTargets
                    Add-LinkWire -Document $Document -WiresNode $wiresNode -WireUid (Get-NextUid) -FromPartUid $downSignal.SignalSourcePartUid -FromName $downSignal.SignalSourceName -ToPartUid $counterPartUid -ToName "CD"
                }

                Add-WireNode -Document $Document -WiresNode $wiresNode -WireUid (Get-NextUid) -FromIdentUid $pvAccessUid -ToPartUid $counterPartUid -ToName "PV"

                $openCon = New-FlgElement -Document $Document -Name "OpenCon"
                $openCon.SetAttribute("UId", [string](Get-NextUid))
                $wireCv = New-FlgElement -Document $Document -Name "Wire"
                $wireCv.SetAttribute("UId", [string](Get-NextUid))
                $fromCv = New-FlgElement -Document $Document -Name "NameCon"
                $fromCv.SetAttribute("UId", [string]$counterPartUid)
                $fromCv.SetAttribute("Name", "CV")
                $null = $wireCv.AppendChild($fromCv)
                $null = $wireCv.AppendChild($openCon)
                $null = $wiresNode.AppendChild($wireCv)
            }
            "CALL" {
                if (-not $action.partName) { throw "CALL action requires partName." }

                $callPartUid = Get-NextUid
                $callPart = New-PartNode -Document $Document -Name ([string]$action.partName) -Uid $callPartUid
                if ($action.PSObject.Properties.Name -contains "version" -and $action.version) {
                    $callPart.SetAttribute("Version", [string]$action.version)
                }

                if ($action.PSObject.Properties.Name -contains "instance" -and $action.instance) {
                    $instanceScope = "GlobalVariable"
                    if ($action.PSObject.Properties.Name -contains "instanceScope" -and $action.instanceScope) {
                        $instanceScope = [string]$action.instanceScope
                    }
                    $instanceNode = New-FlgElement -Document $Document -Name "Instance"
                    $instanceNode.SetAttribute("Scope", $instanceScope)
                    $instanceNode.SetAttribute("UId", [string](Get-NextUid))
                    foreach ($componentName in ([string]$action.instance).Split(".")) {
                        $component = New-FlgElement -Document $Document -Name "Component"
                        $component.SetAttribute("Name", $componentName)
                        $null = $instanceNode.AppendChild($component)
                    }
                    $null = $callPart.AppendChild($instanceNode)
                }

                if ($action.PSObject.Properties.Name -contains "templateValues" -and $action.templateValues) {
                    foreach ($template in @($action.templateValues)) {
                        if (-not $template.name -or -not $template.type) {
                            throw "CALL action templateValues entries require name and type."
                        }
                        Add-TemplateValueNode -Document $Document -Parent $callPart -Name ([string]$template.name) -Type ([string]$template.type) -Value ([string]$template.value)
                    }
                }

                $null = $partsNode.AppendChild($callPart)
                $actionPartRefs.Add([pscustomobject]@{
                    ActionIndex = $currentActionIndex
                    Kind = "CALL"
                    PartUid = $callPartUid
                    DefaultSignalName = ""
                })

                $powerRailEnabled = $false
                if ($action.PSObject.Properties.Name -contains "powerRail" -and $action.powerRail) {
                    $powerRailEnabled = $true
                    $rootTargets.Add([pscustomobject]@{
                        PartUid = $callPartUid
                        Name = "en"
                    })
                }

                if ($action.PSObject.Properties.Name -contains "signalTarget" -and $action.signalTarget) {
                    Assert-SignalPathAvailable -SignalSourcePartUid $signalSourcePartUid -Context "CALL action"
                    Add-LinkWire -Document $Document -WiresNode $wiresNode -WireUid (Get-NextUid) -FromPartUid $signalSourcePartUid -FromName $signalSourceName -ToPartUid $callPartUid -ToName ([string]$action.signalTarget)
                }

                foreach ($input in @($action.inputs)) {
                    if (-not $input.name) { throw "CALL action inputs require name." }

                    if ($input.PSObject.Properties.Name -contains "open" -and $input.open) {
                        Add-OpenToPartWire -Document $Document -WiresNode $wiresNode -WireUid (Get-NextUid) -ToPartUid $callPartUid -ToName ([string]$input.name)
                        continue
                    }

                    $inputSpec = Resolve-AccessSpec -Operand $input -Role ([string]$input.name) -ConditionKind "CALL"
                    $inputAccessUid = Get-NextUid
                    $inputAccess = New-AccessNode -Document $Document -Scope $inputSpec.Scope -Uid $inputAccessUid -Symbol $inputSpec.Symbol -Components $inputSpec.Components -ConstantValue $inputSpec.ConstantValue -ConstantType $inputSpec.ConstantType -ConstantName $inputSpec.ConstantName
                    $null = $partsNode.AppendChild($inputAccess)
                    Add-WireNode -Document $Document -WiresNode $wiresNode -WireUid (Get-NextUid) -FromIdentUid $inputAccessUid -ToPartUid $callPartUid -ToName ([string]$input.name)
                }

                foreach ($output in @($action.outputs)) {
                    if (-not $output.name) { throw "CALL action outputs require name." }

                    if ($output.PSObject.Properties.Name -contains "open" -and $output.open) {
                        Add-PartToOpenWire -Document $Document -WiresNode $wiresNode -WireUid (Get-NextUid) -FromPartUid $callPartUid -FromName ([string]$output.name)
                        continue
                    }

                    $outputTarget = Resolve-TargetSpec -Target $output -ActionKind "CALL output"
                    $outputAccessUid = Get-NextUid
                    $outputAccess = New-AccessNode -Document $Document -Scope $outputTarget.Scope -Uid $outputAccessUid -Symbol $outputTarget.Symbol -Components $outputTarget.Components
                    $null = $partsNode.AppendChild($outputAccess)
                    Add-PartToIdentWire -Document $Document -WiresNode $wiresNode -WireUid (Get-NextUid) -FromPartUid $callPartUid -FromName ([string]$output.name) -ToIdentUid $outputAccessUid
                }

                if (-not $powerRailEnabled -and -not ($action.PSObject.Properties.Name -contains "signalTarget")) {
                    throw "CALL action requires powerRail=true, signalTarget, or both."
                }
            }
            default {
                throw "Unsupported action kind '$kind'. Supported: COIL, SET, RESET, TON, TOF, TP, MOVE, CTU, CTD, CTUD, CALL."
            }
        }
    }

    if ($pendingActionPartUids.Count -gt 0) {
        if ($DeferTerminalPendingOutputs) {
            $deferredTerminalTargets = New-Object System.Collections.Generic.List[object]
            foreach ($pendingPartUid in @($pendingActionPartUids.ToArray())) {
                $deferredTerminalTargets.Add([pscustomobject]@{
                    PartUid = [int]$pendingPartUid
                    Name = "in"
                })
            }
            $pendingActionPartUids.Clear()
        }
        else {
            Assert-SignalPathAvailable -SignalSourcePartUid $signalSourcePartUid -Context "Output action"
            Add-FanoutWire -Document $Document -WiresNode $wiresNode -WireUid (Get-NextUid) -FromPartUid $signalSourcePartUid -FromName $signalSourceName -TargetPartUids @($pendingActionPartUids.ToArray()) -ToName "in"
            $pendingActionPartUids.Clear()
            $deferredTerminalTargets = @()
        }
    }
    else {
        $deferredTerminalTargets = @()
    }

    $deferredTerminalTargetsArray = @()
    if ($deferredTerminalTargets -is [System.Collections.Generic.List[object]]) {
        $deferredTerminalTargetsArray = @($deferredTerminalTargets.ToArray())
    }
    else {
        $deferredTerminalTargetsArray = @($deferredTerminalTargets)
    }

    return [pscustomobject]@{
        FinalSignalSourcePartUid = $signalSourcePartUid
        FinalSignalSourceName = $signalSourceName
        DeferredTerminalTargets = $deferredTerminalTargetsArray
    }
}

function Build-FlgNetFromSpec {
    param(
        [System.Xml.XmlDocument]$Document,
        [pscustomobject]$Spec
    )

    $actions = @()
    if ($Spec.PSObject.Properties.Name -contains "actions" -and $Spec.actions) {
        $actions = @($Spec.actions)
    }

    $branches = @(Get-BranchesFromSpec -Spec $Spec)
    if ($actions.Count -eq 0 -and $branches.Count -eq 0) {
        throw "Spec must contain at least one action or branch."
    }

    Reset-UidGenerator
    $flgNet = New-FlgElement -Document $Document -Name "FlgNet"
    $partsNode = New-FlgElement -Document $Document -Name "Parts"
    $wiresNode = New-FlgElement -Document $Document -Name "Wires"
    $null = $flgNet.AppendChild($partsNode)
    $null = $flgNet.AppendChild($wiresNode)
    $rootTargets = New-Object System.Collections.Generic.List[object]

    $conditionGroups = @(Get-ConditionGroupsFromSpec -Spec $Spec -AllowEmpty)
    $signalSourcePartUid = $null
    $signalSourceName = $null
    if ($conditionGroups.Count -gt 0) {
        $primarySignal = Build-SignalPathFromConditionGroups -Document $Document -PartsNode $partsNode -WiresNode $wiresNode -ConditionGroups $conditionGroups -RootTargets $rootTargets
        $signalSourcePartUid = $primarySignal.SignalSourcePartUid
        $signalSourceName = $primarySignal.SignalSourceName
    }

    $actionPartRefs = New-Object System.Collections.Generic.List[object]
    $currentActionIndex = 0
    $deferredSharedBranchEntryTargets = New-Object System.Collections.Generic.List[object]

    if ($actions.Count -gt 0) {
        $topLevelActionResult = Emit-ActionsFromList -Document $Document -PartsNode $partsNode -WiresNode $wiresNode -Actions $actions -RootTargets $rootTargets -SignalSourcePartUid $signalSourcePartUid -SignalSourceName $signalSourceName -ActionPartRefs $actionPartRefs -CurrentActionIndexRef ([ref]$currentActionIndex) -DeferTerminalPendingOutputs:($branches.Count -gt 0)
        foreach ($deferredTarget in @($topLevelActionResult.DeferredTerminalTargets)) {
            $deferredSharedBranchEntryTargets.Add($deferredTarget)
        }
    }

    foreach ($branch in $branches) {
        $branchActions = @()
        if ($branch.PSObject.Properties.Name -contains "actions" -and $branch.actions) {
            $branchActions = @($branch.actions)
        }
        if ($branchActions.Count -eq 0) {
            throw "Each branch must contain at least one action."
        }

        $branchSignalSourcePartUid = $signalSourcePartUid
        $branchSignalSourceName = $signalSourceName
        $branchConditionGroups = @(Get-ConditionGroupsFromContainer -Container $branch -GroupsProperty "conditionGroups" -ConditionsProperty "conditions" -Label "Branch" -AllowEmpty)
        if ($branchConditionGroups.Count -gt 0) {
            $branchSignal = $null
            if ($null -ne $signalSourcePartUid -and -not [string]::IsNullOrWhiteSpace([string]$signalSourcePartUid)) {
                $branchSignal = Build-SignalPathFromConditionGroups -Document $Document -PartsNode $partsNode -WiresNode $wiresNode -ConditionGroups $branchConditionGroups -RootTargets $rootTargets -UpstreamSignalPartUid $signalSourcePartUid -UpstreamSignalName $signalSourceName -SkipSourceConnection
                foreach ($entryTarget in @($branchSignal.EntryTargets)) {
                    $deferredSharedBranchEntryTargets.Add($entryTarget)
                }
            }
            else {
                $branchSignal = Build-SignalPathFromConditionGroups -Document $Document -PartsNode $partsNode -WiresNode $wiresNode -ConditionGroups $branchConditionGroups -RootTargets $rootTargets
            }

            $branchSignalSourcePartUid = $branchSignal.SignalSourcePartUid
            $branchSignalSourceName = $branchSignal.SignalSourceName
        }

        $null = Emit-ActionsFromList -Document $Document -PartsNode $partsNode -WiresNode $wiresNode -Actions $branchActions -RootTargets $rootTargets -SignalSourcePartUid $branchSignalSourcePartUid -SignalSourceName $branchSignalSourceName -ActionPartRefs $actionPartRefs -CurrentActionIndexRef ([ref]$currentActionIndex)
    }

    if ($deferredSharedBranchEntryTargets.Count -gt 0) {
        Add-MultiTargetLinkWire -Document $Document -WiresNode $wiresNode -WireUid (Get-NextUid) -FromPartUid ([int]$signalSourcePartUid) -FromName $signalSourceName -Targets @($deferredSharedBranchEntryTargets.ToArray())
    }

    if ($rootTargets.Count -gt 0) {
        Add-PowerrailNamedTargetsWire -Document $Document -WiresNode $wiresNode -WireUid (Get-NextUid) -Targets @($rootTargets.ToArray())
    }

    return $flgNet
}

$specRaw = Get-Content -LiteralPath $SpecPath -Raw -Encoding UTF8
$spec = $specRaw | ConvertFrom-Json
if (-not $spec) { throw "Unable to read JSON spec: $SpecPath" }

$topLevelActions = @()
if ($spec.PSObject.Properties.Name -contains "actions" -and $spec.actions) {
    $topLevelActions = @($spec.actions)
}

$conditionGroups = @(Get-ConditionGroupsFromSpec -Spec $spec -AllowEmpty)
$branches = @(Get-BranchesFromSpec -Spec $spec)
$branchConditionGroups = New-Object System.Collections.Generic.List[object]
$allActions = New-Object System.Collections.Generic.List[object]
foreach ($action in $topLevelActions) {
    $allActions.Add($action)
}
foreach ($branch in $branches) {
    foreach ($group in @(Get-ConditionGroupsFromContainer -Container $branch -GroupsProperty "conditionGroups" -ConditionsProperty "conditions" -Label "Branch" -AllowEmpty)) {
        $branchConditionGroups.Add($group)
    }

    if ($branch.PSObject.Properties.Name -contains "actions" -and $branch.actions) {
        foreach ($action in @($branch.actions)) {
            $allActions.Add($action)
        }
    }
}

$allConditionGroups = @($conditionGroups) + @($branchConditionGroups.ToArray())
$totalConditionCount = @($allConditionGroups | ForEach-Object { @($_.conditions).Count } | Measure-Object -Sum).Sum
if ($null -eq $totalConditionCount) { $totalConditionCount = 0 }

$targetDoc = Get-XmlDocument -Path $TargetXml
$knownInstancePaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($path in @(Get-InstancePathsFromDocument -Document $targetDoc)) {
    $null = $knownInstancePaths.Add($path)
}

$timerInstances = New-Object System.Collections.Generic.List[string]
$instanceBackedActions = New-Object System.Collections.Generic.List[string]
foreach ($action in @($allActions.ToArray())) {
    if ($action.kind -in @("TON", "TOF", "TP") -and $action.instance) {
        $timerInstances.Add([string]$action.instance)
    }
    if ($action.kind -in @("TON", "TOF", "TP", "CTU", "CTD", "CTUD") -and $action.instance) {
        $instanceBackedActions.Add([string]$action.instance)
    }
}

$timerInstancesSeen = New-Object System.Collections.Generic.List[string]
$timerInstancesMissing = New-Object System.Collections.Generic.List[string]
foreach ($instancePath in @($timerInstances.ToArray())) {
    if ($knownInstancePaths.Contains($instancePath)) {
        $timerInstancesSeen.Add($instancePath)
    }
    else {
        $timerInstancesMissing.Add($instancePath)
    }
}

$instancePathsSeen = New-Object System.Collections.Generic.List[string]
$instancePathsMissing = New-Object System.Collections.Generic.List[string]
foreach ($instancePath in @($instanceBackedActions.ToArray())) {
    if ($knownInstancePaths.Contains($instancePath)) {
        $instancePathsSeen.Add($instancePath)
    }
    else {
        $instancePathsMissing.Add($instancePath)
    }
}

$units = Select-CompileUnits -Node $targetDoc
$targetUnit = Get-NetworkUnit -Units $units -Index $NetworkIndex
$attributeList = $targetUnit.SelectSingleNode("./*[local-name()='AttributeList']")
if (-not $attributeList) { throw "Target network does not contain an AttributeList node." }

$newFlgNet = Build-FlgNetFromSpec -Document $targetDoc -Spec $spec
$networkSource = $attributeList.SelectSingleNode("./*[local-name()='NetworkSource']")
if (-not $networkSource) {
    $networkSource = $targetDoc.CreateElement("NetworkSource")
    $null = $attributeList.AppendChild($networkSource)
}
else {
    foreach ($child in @($networkSource.ChildNodes)) {
        $null = $networkSource.RemoveChild($child)
    }
}
$null = $networkSource.AppendChild($newFlgNet)

if ($null -ne $spec.title) {
    Set-CompositionText -Unit $targetUnit -CompositionName "Title" -Value ([string]$spec.title)
}
if ($null -ne $spec.comment) {
    Set-CompositionText -Unit $targetUnit -CompositionName "Comment" -Value ([string]$spec.comment)
}

$outputDir = Split-Path -Parent $OutputXml
if ($outputDir) { New-Item -ItemType Directory -Path $outputDir -Force | Out-Null }
$settings = New-Object System.Xml.XmlWriterSettings
$settings.Encoding = New-Object System.Text.UTF8Encoding($false)
$settings.Indent = $true
$writer = [System.Xml.XmlWriter]::Create($OutputXml, $settings)
$targetDoc.Save($writer)
$writer.Close()

[pscustomobject]@{
    TargetXml = (Get-Item -LiteralPath $TargetXml).FullName
    SpecPath = (Get-Item -LiteralPath $SpecPath).FullName
    OutputXml = (Get-Item -LiteralPath $OutputXml).FullName
    NetworkIndex = $NetworkIndex
    ConditionCount = $totalConditionCount
    ConditionGroupCount = $allConditionGroups.Count
    ActionCount = $allActions.Count
    BranchCount = $branches.Count
    SupportedSubset = "contacts-edge-comparisons-or-branches-plus-ton-tof-tp-move-ctu-ctd-ctud-call-and-shared-prefix-branches"
    TonInstanceCount = $timerInstances.Count
    TonInstances = @($timerInstances.ToArray())
    TonInstancesSeenInTargetXml = @($timerInstancesSeen.ToArray())
    TonInstancesMissingFromTargetXml = @($timerInstancesMissing.ToArray())
    StatefulInstanceCount = $instanceBackedActions.Count
    StatefulInstances = @($instanceBackedActions.ToArray())
    StatefulInstancesSeenInTargetXml = @($instancePathsSeen.ToArray())
    StatefulInstancesMissingFromTargetXml = @($instancePathsMissing.ToArray())
} | ConvertTo-Json -Depth 5
