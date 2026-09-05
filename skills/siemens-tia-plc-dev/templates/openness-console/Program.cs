using Siemens.Engineering;
using Siemens.Engineering.Compiler;
using Siemens.Engineering.HW;
using Siemens.Engineering.HW.Features;
using Siemens.Engineering.SW;
using Siemens.Engineering.SW.Blocks;
using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Text.RegularExpressions;

namespace __PROJECT_NAME__
{
    internal sealed class Program
    {
        [STAThread]
        private static int Main(string[] args)
        {
            try
            {
                AppDomain.CurrentDomain.AssemblyResolve += ResolveSiemensAssembly;

                if (args.Length == 0 || args[0] == "help" || args[0] == "--help")
                {
                    Usage();
                    return 0;
                }

                string command = args[0].ToLowerInvariant();
                Dictionary<string, string> options = ParseOptions(args);
                string projectPath = GetOption(options, "--project", Directory.GetCurrentDirectory());
                FileInfo projectFile = ResolveProjectFile(projectPath);

                if (command == "list-plcs")
                {
                    return WithProject(projectFile, delegate(Project project)
                    {
                        Console.WriteLine("Device\tItemPath\tSoftware");
                        foreach (PlcTarget plc in FindPlcs(project))
                        {
                            Console.WriteLine("{0}\t{1}\t{2}", plc.DeviceName, plc.ItemPath, plc.Software.Name);
                        }
                        return 0;
                    });
                }

                if (command == "list-blocks")
                {
                    return WithProject(projectFile, delegate(Project project)
                    {
                        foreach (PlcTarget plc in SelectPlcs(project, options))
                        {
                            Console.WriteLine("# PLC\t{0}\t{1}\t{2}", plc.DeviceName, plc.ItemPath, plc.Software.Name);
                            Console.WriteLine("Name\tType\tNumber\tLanguage");
                            foreach (PlcBlock block in plc.Software.BlockGroup.Blocks)
                            {
                                Console.WriteLine("{0}\t{1}\t{2}\t{3}",
                                    block.Name,
                                    block.GetType().Name,
                                    block.Number,
                                    block.ProgrammingLanguage);
                            }
                        }
                        return 0;
                    });
                }

                if (command == "compile-plc")
                {
                    return WithProject(projectFile, delegate(Project project)
                    {
                        int worst = 0;
                        foreach (PlcTarget plc in SelectPlcs(project, options))
                        {
                            ICompilable compilable = plc.Software.GetService<ICompilable>();
                            if (compilable == null)
                            {
                                Console.WriteLine("COMPILE_SKIPPED\t{0}", plc.Software.Name);
                                continue;
                            }

                            CompilerResult result = compilable.Compile();
                            Console.WriteLine("COMPILE\t{0}\tState={1}\tErrors={2}\tWarnings={3}",
                                plc.Software.Name,
                                result.State,
                                result.ErrorCount,
                                result.WarningCount);

                            if (result.State == CompilerResultState.Error || result.ErrorCount > 0)
                            {
                                worst = 2;
                            }
                            else if (result.State == CompilerResultState.Warning || result.WarningCount > 0)
                            {
                                worst = Math.Max(worst, 1);
                            }
                        }

                        if (HasFlag(options, "--save") && worst < 2)
                        {
                            project.Save();
                            Console.WriteLine("SAVED\t{0}", project.Path.FullName);
                        }

                        return worst;
                    });
                }

                throw new InvalidOperationException("Unknown command: " + command);
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine("ERROR\t{0}", DescribeException(ex));
                return 1;
            }
        }

        private static Assembly ResolveSiemensAssembly(object sender, ResolveEventArgs args)
        {
            AssemblyName requested = new AssemblyName(args.Name);
            if (!requested.Name.StartsWith("Siemens.Engineering", StringComparison.OrdinalIgnoreCase))
            {
                return null;
            }

            string publicApiRoot = GetTiaPortalPublicApiRoot();
            string candidate = Path.Combine(publicApiRoot, requested.Name + ".dll");
            if (File.Exists(candidate))
            {
                return Assembly.LoadFrom(candidate);
            }

            return null;
        }

        private static string GetTiaPortalRoot()
        {
            string configured = Environment.GetEnvironmentVariable("TiaPortalLocation");
            if (!string.IsNullOrWhiteSpace(configured))
            {
                return configured;
            }

            string versionTag = GetTiaPortalVersionTag();
            if (!string.IsNullOrWhiteSpace(versionTag))
            {
                return @"C:\Program Files\Siemens\Automation\Portal " + versionTag;
            }

            return @"C:\Program Files\Siemens\Automation\Portal V16";
        }

        private static string GetTiaPortalPublicApiRoot()
        {
            string configured = Environment.GetEnvironmentVariable("TiaPortalPublicApiPath");
            if (!string.IsNullOrWhiteSpace(configured))
            {
                return configured;
            }

            string root = GetTiaPortalRoot();
            string versionTag = GetTiaPortalVersionTag();
            if (string.Equals(versionTag, "V21", StringComparison.OrdinalIgnoreCase))
            {
                string net48 = Path.Combine(root, "PublicAPI", "V21", "net48");
                if (Directory.Exists(net48))
                {
                    return net48;
                }

                return Path.Combine(root, "PublicAPI", "V21");
            }

            if (!string.IsNullOrWhiteSpace(versionTag))
            {
                return Path.Combine(root, "PublicAPI", versionTag);
            }

            return Path.Combine(root, "PublicAPI", "V16");
        }

        private static string GetTiaPortalVersionTag()
        {
            foreach (string value in new[]
            {
                Environment.GetEnvironmentVariable("CODEX_TIA_PREFERRED_VERSION"),
                Environment.GetEnvironmentVariable("TiaPortalVersion"),
                Environment.GetEnvironmentVariable("TiaPortalLocation")
            })
            {
                if (string.IsNullOrWhiteSpace(value))
                {
                    continue;
                }

                Match match = Regex.Match(value, @"(?i)V(1[6-9]|2[0-1])");
                if (match.Success)
                {
                    return "V" + match.Groups[1].Value;
                }
            }

            return null;
        }

        private static string DescribeException(Exception ex)
        {
            List<string> parts = new List<string>();
            Exception current = ex;
            while (current != null)
            {
                parts.Add(current.GetType().FullName + ": " + current.Message);
                current = current.InnerException;
            }

            return string.Join(" | ", parts);
        }

        private static int WithProject(FileInfo projectFile, Func<Project, int> action)
        {
            using (TiaPortal tia = new TiaPortal(TiaPortalMode.WithoutUserInterface))
            {
                Console.WriteLine("OPENING\t{0}", projectFile.FullName);
                Project project = tia.Projects.Open(projectFile);
                try
                {
                    Console.WriteLine("OPENED\t{0}", projectFile.FullName);
                    return action(project);
                }
                finally
                {
                    project.Close();
                }
            }
        }

        private static List<PlcTarget> FindPlcs(Project project)
        {
            List<PlcTarget> result = new List<PlcTarget>();
            foreach (Device device in project.Devices)
            {
                foreach (DeviceItem item in device.DeviceItems)
                {
                    WalkDeviceItem(device.Name, item.Name, item, result);
                }
            }
            return result;
        }

        private static void WalkDeviceItem(string deviceName, string path, DeviceItem item, List<PlcTarget> result)
        {
            try
            {
                SoftwareContainer container = item.GetService<SoftwareContainer>();
                PlcSoftware plc = container == null ? null : container.Software as PlcSoftware;
                if (plc != null)
                {
                    result.Add(new PlcTarget { DeviceName = deviceName, ItemPath = path, Software = plc });
                }
            }
            catch
            {
                // Keep traversal going for items without software containers.
            }

            foreach (DeviceItem child in item.DeviceItems)
            {
                WalkDeviceItem(deviceName, path + "/" + child.Name, child, result);
            }
        }

        private static List<PlcTarget> SelectPlcs(Project project, Dictionary<string, string> options)
        {
            string filter = GetOption(options, "--plc", "");
            List<PlcTarget> all = FindPlcs(project);
            if (filter.Length == 0)
            {
                return all;
            }

            List<PlcTarget> selected = new List<PlcTarget>();
            foreach (PlcTarget plc in all)
            {
                if (plc.DeviceName.IndexOf(filter, StringComparison.OrdinalIgnoreCase) >= 0 ||
                    plc.ItemPath.IndexOf(filter, StringComparison.OrdinalIgnoreCase) >= 0 ||
                    plc.Software.Name.IndexOf(filter, StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    selected.Add(plc);
                }
            }

            if (selected.Count == 0)
            {
                throw new InvalidOperationException("No PLC matched --plc " + filter);
            }

            return selected;
        }

        private static Dictionary<string, string> ParseOptions(string[] args)
        {
            Dictionary<string, string> options = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            for (int i = 1; i < args.Length; i++)
            {
                string arg = args[i];
                if (!arg.StartsWith("--", StringComparison.Ordinal))
                {
                    continue;
                }
                if (i + 1 < args.Length && !args[i + 1].StartsWith("--", StringComparison.Ordinal))
                {
                    options[arg] = args[i + 1];
                    i++;
                }
                else
                {
                    options[arg] = "true";
                }
            }
            return options;
        }

        private static string GetOption(Dictionary<string, string> options, string key, string fallback)
        {
            string value;
            return options.TryGetValue(key, out value) ? value : fallback;
        }

        private static bool HasFlag(Dictionary<string, string> options, string key)
        {
            return options.ContainsKey(key);
        }

        private static FileInfo ResolveProjectFile(string path)
        {
            if (File.Exists(path))
            {
                return new FileInfo(path);
            }
            if (!Directory.Exists(path))
            {
                throw new DirectoryNotFoundException(path);
            }

            string[] files = Directory.GetFiles(path, "*.ap*", SearchOption.TopDirectoryOnly);
            List<string> supported = new List<string>();
            foreach (string file in files)
            {
                if (Regex.IsMatch(file, @"\.ap(1[6-9]|2[0-1])$", RegexOptions.IgnoreCase))
                {
                    supported.Add(file);
                }
            }

            if (supported.Count == 0)
            {
                throw new FileNotFoundException("No supported TIA project file (.ap16 through .ap21) found in " + path);
            }
            if (supported.Count > 1)
            {
                throw new InvalidOperationException("Multiple supported TIA project files found. Pass the exact --project file.");
            }
            return new FileInfo(supported[0]);
        }

        private static void Usage()
        {
            Console.WriteLine("__PROJECT_NAME__");
            Console.WriteLine("Commands:");
            Console.WriteLine("  list-plcs --project <projectDir|ap16..ap21>");
            Console.WriteLine("  list-blocks --project <projectDir|ap16..ap21> [--plc <name>]");
            Console.WriteLine("  compile-plc --project <projectDir|ap16..ap21> [--plc <name>] [--save]");
        }
    }

    internal sealed class PlcTarget
    {
        public string DeviceName;
        public string ItemPath;
        public PlcSoftware Software;
    }
}
