param(
    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [string]$Title = "New network",

    [string]$Comment = ""
)

$ErrorActionPreference = "Stop"

$spec = [ordered]@{
    title = $Title
    comment = $Comment
    conditions = @(
        [ordered]@{
            kind = "NO"
            symbol = "M0.0"
        },
        [ordered]@{
            kind = "NC"
            symbol = "M0.1"
        }
    )
    actions = @(
        [ordered]@{
            kind = "TON"
            instance = "IEC_Timer_0_DB_1"
            pt = "T#1s"
        },
        [ordered]@{
            kind = "SET"
            symbol = "DB1.SampleAlarm"
        }
    )
    notes = @(
        "Supported condition kinds: NO, NC",
        "Supported action kinds: COIL, SET, RESET, TON",
        "TON feeds its Q output into following actions",
        "Multiple output actions after one signal source are supported"
    )
} | ConvertTo-Json -Depth 6

$outDir = Split-Path -Parent $OutputPath
if ($outDir) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
Set-Content -LiteralPath $OutputPath -Value $spec -Encoding UTF8

[pscustomobject]@{
    OutputPath = (Get-Item -LiteralPath $OutputPath).FullName
} | ConvertTo-Json -Depth 3
