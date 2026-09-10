using System.Diagnostics;
using System.IO.Compression;
using System.Reflection;
using System.Security.Cryptography;
using System.Security.Principal;
using System.Text;
using System.Windows.Forms;

namespace SiemensTIAAgent;

internal static class Program
{
    private const string PayloadResourceName = "SiemensTIAAgent.Payload";
    private const string PayloadMagic = "STAPKG01";

    [STAThread]
    private static int Main(string[] args)
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);

        string? runtimeDirectory = null;
        try
        {
            CleanupExpiredRuntimes();
            runtimeDirectory = CreateRuntimeDirectory();
            ExtractPayload(runtimeDirectory);
            ValidateRuntime(runtimeDirectory);

            if (args.Any(arg => string.Equals(arg, "--verify-only", StringComparison.OrdinalIgnoreCase)))
            {
                return 0;
            }

            return LaunchConsole(runtimeDirectory, args);
        }
        catch (Exception exception)
        {
            MessageBox.Show(
                "Siemens TIA Agent 启动失败。\r\n\r\n" + exception.Message,
                "Siemens TIA Agent",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
            return 1;
        }
        finally
        {
            if (!string.IsNullOrWhiteSpace(runtimeDirectory))
            {
                DeleteRuntimeWithRetries(runtimeDirectory);
            }
        }
    }

    private static string CreateRuntimeDirectory()
    {
        // Codex child agents can read the user's .codex workspace, while their
        // sandbox may reject an otherwise valid runtime under AppData\Local.
        // Keep the decrypted payload temporary and hidden, but place it where
        // the built-in Agent can actually consume the bundled skills.
        string sessionsRoot = GetSessionsRoot();
        Directory.CreateDirectory(sessionsRoot);

        string runtimeDirectory = Path.Combine(
            sessionsRoot,
            $"{Environment.ProcessId}-{Guid.NewGuid():N}");
        Directory.CreateDirectory(runtimeDirectory);
        TryRestrictToCurrentUser(runtimeDirectory);
        File.SetAttributes(runtimeDirectory, File.GetAttributes(runtimeDirectory) | FileAttributes.Hidden | FileAttributes.NotContentIndexed);
        return runtimeDirectory;
    }

    private static string GetSessionsRoot()
    {
        return Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
            ".codex",
            "siemens-tia-agent-runtime",
            "sessions");
    }

    private static void ExtractPayload(string runtimeDirectory)
    {
        using Stream encryptedStream = Assembly.GetExecutingAssembly().GetManifestResourceStream(PayloadResourceName)
            ?? throw new InvalidOperationException("内置运行包缺失，EXE 可能不完整。");
        using var encryptedBuffer = new MemoryStream();
        encryptedStream.CopyTo(encryptedBuffer);
        byte[] payload = encryptedBuffer.ToArray();

        byte[] zipBytes = DecryptAndVerify(payload);
        using var zipBuffer = new MemoryStream(zipBytes, writable: false);
        using var archive = new ZipArchive(zipBuffer, ZipArchiveMode.Read);

        string rootPrefix = Path.GetFullPath(runtimeDirectory).TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
        foreach (ZipArchiveEntry entry in archive.Entries)
        {
            string normalizedName = entry.FullName.Replace('/', Path.DirectorySeparatorChar);
            string destination = Path.GetFullPath(Path.Combine(runtimeDirectory, normalizedName));
            if (!destination.StartsWith(rootPrefix, StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidDataException("运行包包含不安全的文件路径。");
            }

            if (string.IsNullOrEmpty(entry.Name))
            {
                Directory.CreateDirectory(destination);
                continue;
            }

            Directory.CreateDirectory(Path.GetDirectoryName(destination)!);
            entry.ExtractToFile(destination, overwrite: true);
        }
    }

    private static byte[] DecryptAndVerify(byte[] payload)
    {
        byte[] magic = Encoding.ASCII.GetBytes(PayloadMagic);
        const int ivLength = 16;
        const int tagLength = 32;
        int headerLength = magic.Length + ivLength + tagLength;
        if (payload.Length <= headerLength || !payload.AsSpan(0, magic.Length).SequenceEqual(magic))
        {
            throw new InvalidDataException("内置运行包格式无效。");
        }

        byte[] keyMaterial = Convert.FromBase64String(PayloadSecrets.KeyMaterialBase64);
        if (keyMaterial.Length != 64)
        {
            throw new InvalidDataException("内置运行包密钥格式无效。");
        }

        byte[] encryptionKey = keyMaterial[..32];
        byte[] authenticationKey = keyMaterial[32..];
        byte[] iv = payload.AsSpan(magic.Length, ivLength).ToArray();
        byte[] expectedTag = payload.AsSpan(magic.Length + ivLength, tagLength).ToArray();
        byte[] cipherText = payload.AsSpan(headerLength).ToArray();

        byte[] authenticatedData = new byte[magic.Length + iv.Length + cipherText.Length];
        Buffer.BlockCopy(magic, 0, authenticatedData, 0, magic.Length);
        Buffer.BlockCopy(iv, 0, authenticatedData, magic.Length, iv.Length);
        Buffer.BlockCopy(cipherText, 0, authenticatedData, magic.Length + iv.Length, cipherText.Length);
        using var hmac = new HMACSHA256(authenticationKey);
        byte[] actualTag = hmac.ComputeHash(authenticatedData);
        if (!CryptographicOperations.FixedTimeEquals(expectedTag, actualTag))
        {
            throw new CryptographicException("内置运行包完整性校验失败，EXE 可能已被修改。");
        }

        using Aes aes = Aes.Create();
        aes.KeySize = 256;
        aes.Key = encryptionKey;
        aes.IV = iv;
        aes.Mode = CipherMode.CBC;
        aes.Padding = PaddingMode.PKCS7;
        using ICryptoTransform decryptor = aes.CreateDecryptor();
        return decryptor.TransformFinalBlock(cipherText, 0, cipherText.Length);
    }

    private static void ValidateRuntime(string runtimeDirectory)
    {
        string consolePath = GetConsolePath(runtimeDirectory);
        string invokePath = GetInvokePath(runtimeDirectory);
        string profilesPath = Path.Combine(
            runtimeDirectory,
            "skills",
            "siemens-tia-plc-dev",
            "agents",
            "siemens-agent-profiles.json");

        foreach (string requiredPath in new[] { consolePath, invokePath, profilesPath })
        {
            if (!File.Exists(requiredPath))
            {
                throw new FileNotFoundException("运行包缺少必要组件。", requiredPath);
            }
        }
    }

    private static int LaunchConsole(string runtimeDirectory, string[] args)
    {
        string consolePath = GetConsolePath(runtimeDirectory);
        string invokePath = GetInvokePath(runtimeDirectory);
        string? projectPath = GetOptionValue(args, "--project");

        var startInfo = new ProcessStartInfo
        {
            FileName = consolePath,
            UseShellExecute = false,
            WorkingDirectory = ResolveWorkingDirectory(projectPath, runtimeDirectory)
        };
        startInfo.ArgumentList.Add("--invoke");
        startInfo.ArgumentList.Add(invokePath);
        if (!string.IsNullOrWhiteSpace(projectPath))
        {
            startInfo.ArgumentList.Add("--project");
            startInfo.ArgumentList.Add(projectPath);
        }
        startInfo.Environment["SIEMENS_TIA_PROTECTED_RUNTIME"] = "1";
        startInfo.Environment["SIEMENS_TIA_RUNTIME_ROOT"] = runtimeDirectory;

        using Process process = Process.Start(startInfo)
            ?? throw new InvalidOperationException("无法启动 PLCDevConsole.exe。");
        process.WaitForExit();
        return process.ExitCode;
    }

    private static string GetConsolePath(string runtimeDirectory) => Path.Combine(
        runtimeDirectory,
        "skills",
        "siemens-tia-plc-dev",
        "app",
        "bin",
        "PLCDevConsole.exe");

    private static string GetInvokePath(string runtimeDirectory) => Path.Combine(
        runtimeDirectory,
        "skills",
        "siemens-tia-plc-dev",
        "scripts",
        "invoke-siemens-plc-dev.ps1");

    private static string? GetOptionValue(string[] args, string option)
    {
        for (int index = 0; index < args.Length - 1; index++)
        {
            if (string.Equals(args[index], option, StringComparison.OrdinalIgnoreCase))
            {
                return args[index + 1];
            }
        }
        return null;
    }

    private static string ResolveWorkingDirectory(string? projectPath, string fallback)
    {
        if (string.IsNullOrWhiteSpace(projectPath))
        {
            return fallback;
        }
        if (Directory.Exists(projectPath))
        {
            return Path.GetFullPath(projectPath);
        }
        if (File.Exists(projectPath))
        {
            return Path.GetDirectoryName(Path.GetFullPath(projectPath)) ?? fallback;
        }
        return fallback;
    }

    private static void TryRestrictToCurrentUser(string directory)
    {
        try
        {
            string? sid = WindowsIdentity.GetCurrent().User?.Value;
            if (string.IsNullOrWhiteSpace(sid))
            {
                return;
            }

            var startInfo = new ProcessStartInfo
            {
                FileName = "icacls.exe",
                UseShellExecute = false,
                CreateNoWindow = true
            };
            startInfo.ArgumentList.Add(directory);
            startInfo.ArgumentList.Add("/inheritance:r");
            startInfo.ArgumentList.Add("/grant:r");
            startInfo.ArgumentList.Add($"*{sid}:(OI)(CI)F");
            startInfo.ArgumentList.Add("/Q");
            using Process? process = Process.Start(startInfo);
            process?.WaitForExit(5000);
        }
        catch
        {
            // The runtime still resides inside the current user's LocalAppData if ACL tightening is unavailable.
        }
    }

    private static void CleanupExpiredRuntimes()
    {
        string sessionsRoot = GetSessionsRoot();
        if (!Directory.Exists(sessionsRoot))
        {
            return;
        }

        foreach (string directory in Directory.EnumerateDirectories(sessionsRoot))
        {
            try
            {
                if (Directory.GetCreationTimeUtc(directory) < DateTime.UtcNow.AddDays(-1))
                {
                    Directory.Delete(directory, recursive: true);
                }
            }
            catch
            {
                // Ignore a runtime that is still in use or owned by another active instance.
            }
        }
    }

    private static void DeleteRuntimeWithRetries(string runtimeDirectory)
    {
        for (int attempt = 0; attempt < 5; attempt++)
        {
            try
            {
                if (Directory.Exists(runtimeDirectory))
                {
                    File.SetAttributes(runtimeDirectory, FileAttributes.Normal);
                    Directory.Delete(runtimeDirectory, recursive: true);
                }
                return;
            }
            catch
            {
                Thread.Sleep(300 * (attempt + 1));
            }
        }
    }
}
