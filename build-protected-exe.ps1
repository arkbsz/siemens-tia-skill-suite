param(
    [string]$OutputDirectory = "",

    [string]$Version = "1.0.0",

    [string]$CertificateThumbprint = ""
)

$ErrorActionPreference = "Stop"
$packageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$launcherProject = Join-Path $packageRoot "packaging\SiemensTIAAgent\SiemensTIAAgent.csproj"
$generatedRoot = Join-Path $packageRoot "packaging\SiemensTIAAgent\Generated"
$consoleBuildScript = Join-Path $packageRoot "skills\siemens-tia-plc-dev\scripts\build-plc-dev-console-exe.ps1"

if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $packageRoot "protected-release"
}

foreach ($requiredPath in @($launcherProject, $consoleBuildScript)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Required build input was not found: $requiredPath"
    }
}

$dotnet = Get-Command dotnet.exe -ErrorAction SilentlyContinue
if (-not $dotnet) {
    throw "The .NET SDK is required to build the protected single-file application."
}

$consoleBuildOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $consoleBuildScript -Force
if ($LASTEXITCODE -ne 0) {
    throw "PLCDevConsole.exe compilation failed."
}
$consoleBuild = ($consoleBuildOutput | Out-String).Trim() | ConvertFrom-Json

$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
$tempRoot = Join-Path $tempBase ("SiemensTIAAgentBuild-" + [guid]::NewGuid().ToString("N"))
$stageRoot = Join-Path $tempRoot "payload"
$zipPath = Join-Path $tempRoot "payload.zip"
$publishRoot = Join-Path $tempRoot "publish"
New-Item -ItemType Directory -Path $stageRoot, $publishRoot, $generatedRoot, $OutputDirectory -Force | Out-Null

try {
    $skillsRoot = Join-Path $packageRoot "skills"
    $skillsToBundle = @("siemens-tia-plc-dev", "siemens-wincc-hmi-dev", "tia-portal-v17", "codex-tia-client")
    foreach ($skillName in $skillsToBundle) {
        $sourceRoot = Join-Path $skillsRoot $skillName
        if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
            throw "Bundled skill was not found: $sourceRoot"
        }

        foreach ($file in Get-ChildItem -LiteralPath $sourceRoot -Recurse -File) {
            $relativeToSkill = $file.FullName.Substring($sourceRoot.Length).TrimStart('\')
            if ($relativeToSkill -match '(^|\\)(__pycache__|\.git)(\\|$)' -or $file.Extension -eq ".pyc") {
                continue
            }
            if ($relativeToSkill -match '^app\\bin\\' -and $file.Name -ne "PLCDevConsole.exe") {
                continue
            }
            if ($skillName -eq "siemens-tia-plc-dev" -and $relativeToSkill -eq "app\PLCDevConsoleWin.cs") {
                continue
            }

            $destination = Join-Path $stageRoot (Join-Path "skills\$skillName" $relativeToSkill)
            New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
            Copy-Item -LiteralPath $file.FullName -Destination $destination -Force
        }
    }

    foreach ($rootFile in @("dependencies.json", "LICENSE")) {
        $source = Join-Path $packageRoot $rootFile
        if (Test-Path -LiteralPath $source -PathType Leaf) {
            Copy-Item -LiteralPath $source -Destination (Join-Path $stageRoot $rootFile) -Force
        }
    }

    $runtimeManifest = [ordered]@{
        schemaVersion = 1
        product = "Siemens TIA Agent"
        version = $Version
        builtAt = (Get-Date).ToUniversalTime().ToString("o")
        protectedContainer = "AES-256-CBC + HMAC-SHA256"
        skills = $skillsToBundle
        console = "skills\siemens-tia-plc-dev\app\bin\PLCDevConsole.exe"
    }
    $runtimeManifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $stageRoot "runtime-manifest.json") -Encoding UTF8

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::CreateFromDirectory(
        $stageRoot,
        $zipPath,
        [IO.Compression.CompressionLevel]::Optimal,
        $false)

    $keyMaterial = New-Object byte[] 64
    $iv = New-Object byte[] 16
    $random = [Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $random.GetBytes($keyMaterial)
        $random.GetBytes($iv)
    }
    finally {
        $random.Dispose()
    }

    $zipBytes = [IO.File]::ReadAllBytes($zipPath)
    $aes = [Security.Cryptography.Aes]::Create()
    try {
        $aes.KeySize = 256
        $aes.Key = [byte[]]$keyMaterial[0..31]
        $aes.IV = $iv
        $aes.Mode = [Security.Cryptography.CipherMode]::CBC
        $aes.Padding = [Security.Cryptography.PaddingMode]::PKCS7
        $encryptor = $aes.CreateEncryptor()
        try {
            $cipherBytes = $encryptor.TransformFinalBlock($zipBytes, 0, $zipBytes.Length)
        }
        finally {
            $encryptor.Dispose()
        }
    }
    finally {
        $aes.Dispose()
    }

    $magic = [Text.Encoding]::ASCII.GetBytes("STAPKG01")
    $authenticatedData = New-Object byte[] ($magic.Length + $iv.Length + $cipherBytes.Length)
    [Buffer]::BlockCopy($magic, 0, $authenticatedData, 0, $magic.Length)
    [Buffer]::BlockCopy($iv, 0, $authenticatedData, $magic.Length, $iv.Length)
    [Buffer]::BlockCopy($cipherBytes, 0, $authenticatedData, $magic.Length + $iv.Length, $cipherBytes.Length)
    $hmac = New-Object Security.Cryptography.HMACSHA256 -ArgumentList (,([byte[]]$keyMaterial[32..63]))
    try {
        $tag = $hmac.ComputeHash($authenticatedData)
    }
    finally {
        $hmac.Dispose()
    }

    $encryptedPayload = New-Object byte[] ($magic.Length + $iv.Length + $tag.Length + $cipherBytes.Length)
    [Buffer]::BlockCopy($magic, 0, $encryptedPayload, 0, $magic.Length)
    [Buffer]::BlockCopy($iv, 0, $encryptedPayload, $magic.Length, $iv.Length)
    [Buffer]::BlockCopy($tag, 0, $encryptedPayload, $magic.Length + $iv.Length, $tag.Length)
    [Buffer]::BlockCopy($cipherBytes, 0, $encryptedPayload, $magic.Length + $iv.Length + $tag.Length, $cipherBytes.Length)

    $payloadPath = Join-Path $generatedRoot "payload.bin"
    [IO.File]::WriteAllBytes($payloadPath, $encryptedPayload)
    $secretSource = @"
namespace SiemensTIAAgent;

internal static class PayloadSecrets
{
    internal const string KeyMaterialBase64 = "$([Convert]::ToBase64String($keyMaterial))";
}
"@
    [IO.File]::WriteAllText(
        (Join-Path $generatedRoot "PayloadSecrets.g.cs"),
        $secretSource,
        (New-Object Text.UTF8Encoding($false)))

    & $dotnet.Source publish $launcherProject -c Release -r win-x64 --self-contained true -o $publishRoot --nologo
    if ($LASTEXITCODE -ne 0) {
        throw "Protected launcher compilation failed."
    }

    $publishedExe = Join-Path $publishRoot "SiemensTIAAgent.exe"
    if (-not (Test-Path -LiteralPath $publishedExe -PathType Leaf)) {
        throw "Published single-file executable was not found: $publishedExe"
    }

    $outputExe = Join-Path $OutputDirectory "SiemensTIAAgent.exe"
    Copy-Item -LiteralPath $publishedExe -Destination $outputExe -Force

    if ($CertificateThumbprint) {
        $certificate = Get-ChildItem -LiteralPath "Cert:\CurrentUser\My\$CertificateThumbprint" -ErrorAction Stop
        $signature = Set-AuthenticodeSignature -LiteralPath $outputExe -Certificate $certificate -HashAlgorithm SHA256
        if ($signature.Status -ne "Valid") {
            throw "Authenticode signing failed: $($signature.StatusMessage)"
        }
    }

    $verification = Start-Process -FilePath $outputExe -ArgumentList "--verify-only" -PassThru -Wait -WindowStyle Hidden
    if ($verification.ExitCode -ne 0) {
        throw "Protected executable self-verification failed with exit code $($verification.ExitCode)."
    }

    $hash = (Get-FileHash -LiteralPath $outputExe -Algorithm SHA256).Hash
    [pscustomobject]@{
        Status = "Built"
        Product = "Siemens TIA Agent"
        Version = $Version
        ExePath = (Get-Item -LiteralPath $outputExe).FullName
        Bytes = (Get-Item -LiteralPath $outputExe).Length
        Sha256 = $hash
        PayloadFiles = @(Get-ChildItem -LiteralPath $stageRoot -Recurse -File).Count
        PayloadProtection = "AES-256-CBC + HMAC-SHA256"
        Signed = [bool]$CertificateThumbprint
        SelfTest = "Passed"
    } | ConvertTo-Json -Depth 5
}
finally {
    $resolvedTempRoot = [IO.Path]::GetFullPath($tempRoot)
    if ($resolvedTempRoot.StartsWith($tempBase, [StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path -Leaf $resolvedTempRoot) -like "SiemensTIAAgentBuild-*") {
        try { [IO.Directory]::Delete($resolvedTempRoot, $true) } catch { }
    }
}
