function Get-TiaBridgeVersionNumber {
    param(
        [string]$Value
    )

    if ($Value -and $Value -match "V?(?<Version>\d+)$") {
        return $Matches.Version
    }

    return $null
}

function Resolve-TiaBridgeSkill {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SkillsRoot
    )

    $availableSkills = @(
        Get-ChildItem -LiteralPath $SkillsRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "tia-portal-v*" } |
            Sort-Object { [int](Get-TiaBridgeVersionNumber $_.Name) } -Descending
    )

    $candidateVersions = [System.Collections.Generic.List[string]]::new()

    $preferred = Get-TiaBridgeVersionNumber $env:CODEX_TIA_PREFERRED_VERSION
    if ($preferred) {
        $candidateVersions.Add($preferred)
    }

    $locationVersion = Get-TiaBridgeVersionNumber $env:TiaPortalLocation
    if ($locationVersion) {
        $candidateVersions.Add($locationVersion)
    }

    foreach ($skill in $availableSkills) {
        $skillVersion = Get-TiaBridgeVersionNumber $skill.Name
        if ($skillVersion) {
            $candidateVersions.Add($skillVersion)
        }
    }

    $checked = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($version in $candidateVersions) {
        if (-not $checked.Add($version)) {
            continue
        }

        $skillPath = Join-Path $SkillsRoot ("tia-portal-v{0}" -f $version)
        if (Test-Path -LiteralPath $skillPath) {
            return [pscustomobject]@{
                Version = "V$version"
                SkillPath = $skillPath
            }
        }
    }

    throw "No local TIA Portal bridge skill was found under $SkillsRoot. Expected a sibling skill such as tia-portal-v17."
}

function Resolve-TiaBridgeScript {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SkillPath,

        [Parameter(Mandatory = $true)]
        [string[]]$Candidates
    )

    foreach ($candidate in $Candidates) {
        $path = Join-Path $SkillPath $candidate
        if (Test-Path -LiteralPath $path) {
            return $path
        }
    }

    throw "Unable to resolve any of these bridge scripts under ${SkillPath}: $($Candidates -join ', ')"
}
