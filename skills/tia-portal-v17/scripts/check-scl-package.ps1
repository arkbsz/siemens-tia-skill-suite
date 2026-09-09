param(
    [Parameter(Mandatory = $true)]
    [string]$Path
)

$ErrorActionPreference = "Stop"

$root = Get-Item -LiteralPath $Path
$files = if ($root.PSIsContainer) {
    Get-ChildItem -LiteralPath $root.FullName -Recurse -File -Include *.scl
} else {
    @($root)
}

$results = foreach ($file in $files) {
    $text = Get-Content -LiteralPath $file.FullName -Raw
    $issues = New-Object System.Collections.Generic.List[string]

    if ($text -match 'FUNCTION_BLOCK\s+"[^"]+"' -and $text -notmatch 'END_FUNCTION_BLOCK') {
        $issues.Add("Missing END_FUNCTION_BLOCK")
    }
    if ($text -match 'FUNCTION\s+"[^"]+"' -and $text -notmatch 'END_FUNCTION') {
        $issues.Add("Missing END_FUNCTION")
    }
    if ($text -match 'TYPE\s+"[^"]+"' -and $text -notmatch 'END_TYPE') {
        $issues.Add("Missing END_TYPE")
    }
    if ($text -match '\bAlarmWord\s*:=' -and $text -notmatch '#AlarmWord\s*:=') {
        $issues.Add("Possible local variable assignment missing # prefix")
    }
    if ($text -match 'VAR_TEMP[\s\S]*\b(\w+)\s*:\s*' ) {
        # Lightweight check only; TIA compile remains authoritative.
    }

    [pscustomobject]@{
        File = $file.FullName
        Ok = $issues.Count -eq 0
        Issues = @($issues)
    }
}

$results | ConvertTo-Json -Depth 5
