$script:TiaSupportedVersionMajors = @(17, 18, 19, 20, 21)

function Get-TiaSupportedVersionMajors {
    return @($script:TiaSupportedVersionMajors)
}

function ConvertTo-TiaMajorVersion {
    param(
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    if ($Value -match '(?i)(?:^|[^0-9])V?(?<Version>1[7-9]|2[0-1])(?:$|[^0-9])') {
        return [int]$Matches.Version
    }

    return $null
}

function Get-TiaDefaultRoot {
    param(
        [Parameter(Mandatory = $true)]
        [int]$VersionMajor
    )

    return "C:\Program Files\Siemens\Automation\Portal V$VersionMajor"
}

function Get-TiaProjectFiles {
    param(
        [string]$ProjectPath
    )

    if ([string]::IsNullOrWhiteSpace($ProjectPath) -or -not (Test-Path -LiteralPath $ProjectPath)) {
        return @()
    }

    $item = Get-Item -LiteralPath $ProjectPath
    if (-not $item.PSIsContainer) {
        if ($item.Extension -match '^\.ap(1[7-9]|2[0-1])$') {
            return @($item)
        }

        return @()
    }

    return @(
        Get-ChildItem -LiteralPath $item.FullName -File -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -match '^\.ap(1[7-9]|2[0-1])$' } |
            Sort-Object Name
    )
}

function Get-TiaProjectVersion {
    param(
        [string]$ProjectPath
    )

    $projectFiles = Get-TiaProjectFiles -ProjectPath $ProjectPath
    if ($projectFiles.Count -eq 1) {
        return ConvertTo-TiaMajorVersion -Value $projectFiles[0].Extension
    }

    $versions = @(
        $projectFiles |
            ForEach-Object { ConvertTo-TiaMajorVersion -Value $_.Extension } |
            Where-Object { $null -ne $_ } |
            Sort-Object -Unique
    )

    if ($versions.Count -eq 1) {
        return [int]$versions[0]
    }

    return $null
}

function Get-TiaInstalledVersionMajors {
    $versions = [System.Collections.Generic.HashSet[int]]::new()

    foreach ($root in @(
        "HKLM:\SOFTWARE\Siemens\Automation\Openness",
        "HKLM:\SOFTWARE\WOW6432Node\Siemens\Automation\Openness"
    )) {
        try {
            if (-not (Test-Path -LiteralPath $root)) {
                continue
            }

            foreach ($key in Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue) {
                $major = ConvertTo-TiaMajorVersion -Value (Split-Path -Leaf $key.Name)
                if ($major) {
                    $versions.Add([int]$major) | Out-Null
                }
            }
        }
        catch {
        }
    }

    foreach ($major in Get-TiaSupportedVersionMajors) {
        if (Test-Path -LiteralPath (Get-TiaDefaultRoot -VersionMajor $major)) {
            $versions.Add([int]$major) | Out-Null
        }
    }

    return @($versions) | Sort-Object -Descending
}

function Get-TiaPublicApiCandidates {
    param(
        [Parameter(Mandatory = $true)]
        [int]$VersionMajor,

        [Parameter(Mandatory = $true)]
        [string]$TiaRoot,

        [string]$ExplicitPublicApiPath
    )

    $candidates = [System.Collections.Generic.List[string]]::new()

    if (-not [string]::IsNullOrWhiteSpace($ExplicitPublicApiPath)) {
        $candidates.Add($ExplicitPublicApiPath)
    }

    if ($VersionMajor -ge 21) {
        $candidates.Add((Join-Path $TiaRoot "PublicAPI\V$VersionMajor\net48"))
        $candidates.Add((Join-Path $TiaRoot "PublicAPI\V$VersionMajor"))
    }
    else {
        $candidates.Add((Join-Path $TiaRoot "PublicAPI\V$VersionMajor"))
    }

    return @($candidates | Select-Object -Unique)
}

function Get-TiaSchemaRootCandidates {
    param(
        [string]$PublicApiRoot
    )

    $candidates = [System.Collections.Generic.List[string]]::new()
    if ([string]::IsNullOrWhiteSpace($PublicApiRoot)) {
        return @()
    }

    $candidates.Add((Join-Path $PublicApiRoot "Schemas"))
    if ((Split-Path -Leaf $PublicApiRoot) -ieq "net48") {
        $candidates.Add((Join-Path (Split-Path -Parent $PublicApiRoot) "Schemas"))
    }

    return @($candidates | Select-Object -Unique)
}

function Get-TiaCompatibilityNotes {
    param(
        [Parameter(Mandatory = $true)]
        [int]$VersionMajor
    )

    $notes = [System.Collections.Generic.List[string]]::new()

    switch ($VersionMajor) {
        17 {
            $notes.Add("V17 is the legacy monolithic Openness layout that uses Siemens.Engineering.dll.")
            $notes.Add("Use XML and exported LAD/FBD artifacts as the main reviewable surface.")
        }
        18 {
            $notes.Add("V18 keeps the monolithic assembly layout but tightens SimaticML handling with mandatory namespace attributes.")
            $notes.Add("V18 introduced additional Openness-side validation such as stricter password checks and MissingProductException handling.")
        }
        19 {
            $notes.Add("V19 adds NamedValueConstant/NamedValueType support in SimaticML and changes several engineering-side behaviors.")
            $notes.Add("V19 also removes legacy CAx command-line automation and changes some UMAC and labeling behavior.")
        }
        20 {
            $notes.Add("V20 introduces SIMATIC SD text-based document workflows for graphical languages and keeps backward compatibility for rebuilt applications in scope.")
            $notes.Add("V20 adds stricter validation for renamed PLC tags and constants.")
        }
        21 {
            $notes.Add("V21 switches to modular Openness assemblies under PublicAPI\\V21\\net48 and expands document workflows.")
            $notes.Add("V21 can import SimaticML files exported from V18-V21 and supports richer SIMATIC SD coverage than V20.")
        }
    }

    return @($notes)
}

function Get-TiaRequestedVersionMajors {
    param(
        [string]$ProjectPath,

        [string]$PreferredVersion
    )

    $requested = [System.Collections.Generic.List[int]]::new()
    foreach ($major in @(
        Get-TiaProjectVersion -ProjectPath $ProjectPath
        ConvertTo-TiaMajorVersion -Value $PreferredVersion
    )) {
        if ($major -and -not $requested.Contains([int]$major)) {
            $requested.Add([int]$major)
        }
    }

    return @($requested)
}

function Get-TiaLocationHint {
    param(
        [string]$ProjectPath,

        [string]$PreferredVersion,

        [string]$ExplicitLocation,

        [string]$EnvironmentLocation
    )

    if (-not [string]::IsNullOrWhiteSpace($ExplicitLocation)) {
        return $ExplicitLocation
    }

    if ([string]::IsNullOrWhiteSpace($EnvironmentLocation)) {
        return $null
    }

    $requestedMajors = Get-TiaRequestedVersionMajors -ProjectPath $ProjectPath -PreferredVersion $PreferredVersion
    if ($requestedMajors.Count -eq 0) {
        return $EnvironmentLocation
    }

    $environmentMajor = ConvertTo-TiaMajorVersion -Value $EnvironmentLocation
    if (-not $environmentMajor) {
        return $EnvironmentLocation
    }

    if ($requestedMajors -contains [int]$environmentMajor) {
        return $EnvironmentLocation
    }

    return $null
}

function Get-TiaPublicApiHint {
    param(
        [string]$ProjectPath,

        [string]$PreferredVersion,

        [string]$ExplicitPublicApiPath,

        [string]$EnvironmentPublicApiPath
    )

    if (-not [string]::IsNullOrWhiteSpace($ExplicitPublicApiPath)) {
        return $ExplicitPublicApiPath
    }

    if ([string]::IsNullOrWhiteSpace($EnvironmentPublicApiPath)) {
        return $null
    }

    $requestedMajors = Get-TiaRequestedVersionMajors -ProjectPath $ProjectPath -PreferredVersion $PreferredVersion
    if ($requestedMajors.Count -eq 0) {
        return $EnvironmentPublicApiPath
    }

    $environmentMajor = ConvertTo-TiaMajorVersion -Value $EnvironmentPublicApiPath
    if (-not $environmentMajor) {
        return $EnvironmentPublicApiPath
    }

    if ($requestedMajors -contains [int]$environmentMajor) {
        return $EnvironmentPublicApiPath
    }

    return $null
}

function Resolve-TiaPortalEnvironment {
    param(
        [string]$ProjectPath,

        [string]$PreferredVersion,

        [string]$TiaPortalLocation,

        [string]$TiaPortalPublicApiPath
    )

    $preferredMajor = ConvertTo-TiaMajorVersion -Value $PreferredVersion
    $projectMajor = Get-TiaProjectVersion -ProjectPath $ProjectPath
    $locationMajor = ConvertTo-TiaMajorVersion -Value $TiaPortalLocation
    $installedMajors = Get-TiaInstalledVersionMajors

    $pinnedMajors = [System.Collections.Generic.List[int]]::new()
    foreach ($major in @($projectMajor, $preferredMajor, $locationMajor)) {
        if ($major -and -not $pinnedMajors.Contains([int]$major)) {
            $pinnedMajors.Add([int]$major)
        }
    }

    $searchMajors = if ($pinnedMajors.Count -gt 0) {
        @($pinnedMajors)
    }
    else {
        $fallback = [System.Collections.Generic.List[int]]::new()
        foreach ($major in $installedMajors) {
            if (-not $fallback.Contains([int]$major)) {
                $fallback.Add([int]$major)
            }
        }
        foreach ($major in (Get-TiaSupportedVersionMajors | Sort-Object -Descending)) {
            if (-not $fallback.Contains([int]$major)) {
                $fallback.Add([int]$major)
            }
        }
        @($fallback)
    }

    $resolvedVersion = $null
    foreach ($major in $searchMajors) {

        $root = if ([string]::IsNullOrWhiteSpace($TiaPortalLocation)) {
            Get-TiaDefaultRoot -VersionMajor $major
        }
        else {
            $TiaPortalLocation
        }

        $publicApiCandidates = Get-TiaPublicApiCandidates -VersionMajor $major -TiaRoot $root -ExplicitPublicApiPath $TiaPortalPublicApiPath
        $publicApiRoot = $null
        foreach ($candidate in $publicApiCandidates) {
            if (Test-Path -LiteralPath $candidate) {
                $publicApiRoot = $candidate
                break
            }
        }
        if (-not $publicApiRoot -and $publicApiCandidates.Count -gt 0) {
            $publicApiRoot = $publicApiCandidates[0]
        }

        $schemaRootCandidates = Get-TiaSchemaRootCandidates -PublicApiRoot $publicApiRoot
        $schemaRoot = $null
        foreach ($candidate in $schemaRootCandidates) {
            if (Test-Path -LiteralPath $candidate) {
                $schemaRoot = $candidate
                break
            }
        }
        if (-not $schemaRoot -and $schemaRootCandidates.Count -gt 0) {
            $schemaRoot = $schemaRootCandidates[0]
        }

        if ($major -ge 21) {
            $primaryReferencePaths = @(
                Join-Path $publicApiRoot "Siemens.Engineering.Base.dll"
                Join-Path $publicApiRoot "Siemens.Engineering.Step7.dll"
            )
            $engineeringAssemblyPath = Join-Path $publicApiRoot "Siemens.Engineering.Base.dll"
        }
        else {
            $primaryReferencePaths = @(
                Join-Path $publicApiRoot "Siemens.Engineering.dll"
            )
            $engineeringAssemblyPath = Join-Path $publicApiRoot "Siemens.Engineering.dll"
        }

        $referencePaths = @($primaryReferencePaths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        $existingReferencePaths = @($referencePaths | Where-Object { Test-Path -LiteralPath $_ })
        $portalExe = Join-Path $root "Bin\Siemens.Automation.Portal.exe"

        $resolvedVersion = [pscustomobject]@{
            VersionMajor = [int]$major
            VersionTag = "V$major"
            TiaRoot = $root
            PublicApiRoot = $publicApiRoot
            SchemaRoot = $schemaRoot
            PortalExePath = $portalExe
            ProjectExtension = ".ap$major"
            TiaRootExists = Test-Path -LiteralPath $root
            PublicApiExists = if ($publicApiRoot) { Test-Path -LiteralPath $publicApiRoot } else { $false }
            SchemaRootExists = if ($schemaRoot) { Test-Path -LiteralPath $schemaRoot } else { $false }
            PortalExeExists = Test-Path -LiteralPath $portalExe
            EngineeringAssemblyPath = $engineeringAssemblyPath
            EngineeringAssemblyExists = if ($engineeringAssemblyPath) { Test-Path -LiteralPath $engineeringAssemblyPath } else { $false }
            PrimaryReferencePaths = $referencePaths
            ExistingPrimaryReferencePaths = $existingReferencePaths
            UsesModularAssemblies = ($major -ge 21)
            SupportsSimaticSd = ($major -ge 20)
            SupportsExpandedSimaticSd = ($major -ge 21)
            SupportsNamedValueConstants = ($major -ge 19)
            RequiresSimaticMlNamespace = ($major -ge 18)
            SupportsSimaticMlImportFromV18Plus = ($major -ge 21)
            InstalledVersionMajors = @($installedMajors)
            ProjectVersionMajor = $projectMajor
            PreferredVersionMajor = $preferredMajor
            CompatibilityNotes = Get-TiaCompatibilityNotes -VersionMajor $major
        }

        if ($pinnedMajors.Count -gt 0) {
            break
        }

        if ($resolvedVersion.TiaRootExists -or $resolvedVersion.PublicApiExists -or $resolvedVersion.EngineeringAssemblyExists) {
            break
        }
    }

    if (-not $resolvedVersion) {
        throw "Unable to resolve a supported TIA Portal environment for V17 through V21."
    }

    return $resolvedVersion
}
