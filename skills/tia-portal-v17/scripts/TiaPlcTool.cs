using Siemens.Engineering;
using Siemens.Engineering.Compiler;
using Siemens.Engineering.HW;
using Siemens.Engineering.HW.Features;
using Siemens.Engineering.SW;
using Siemens.Engineering.SW.Blocks;
using Siemens.Engineering.SW.ExternalSources;
using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;

namespace CodexTiaPortalV17
{
    internal sealed class Program
    {
        [STAThread]
        private static int Main(string[] args)
        {
            try
            {
                if (args.Length == 0 || args[0] == "help" || args[0] == "--help")
                {
                    Usage();
                    return 0;
                }

                string command = args[0].ToLowerInvariant();
                Dictionary<string, string> options = ParseOptions(args);
                bool needsProject = command != "create-project";
                string projectPath = GetOption(options, "--project", Directory.GetCurrentDirectory());
                FileInfo projectFile = needsProject ? ResolveProjectFile(projectPath) : null;

                if (command == "create-project")
                {
                    return CreateProject(options);
                }

                if (command == "hold-project")
                {
                    return HoldProject(projectFile, options);
                }

                if (command == "list-plcs")
                {
                    return WithProject(projectFile, false, options, delegate(Project project)
                    {
                        List<PlcTarget> plcs = FindPlcs(project);
                        Console.WriteLine("Device\tItemPath\tSoftware");
                        foreach (PlcTarget plc in plcs)
                        {
                            Console.WriteLine("{0}\t{1}\t{2}", plc.DeviceName, plc.ItemPath, plc.Software.Name);
                        }
                        return 0;
                    });
                }

                if (command == "list-devices")
                {
                    return WithProject(projectFile, false, options, delegate(Project project)
                    {
                        Console.WriteLine("Name\tTypeIdentifier");
                        foreach (Device device in project.Devices)
                        {
                            Console.WriteLine("{0}\t{1}", device.Name, device.TypeIdentifier);
                            foreach (DeviceItem item in device.DeviceItems)
                            {
                                PrintDeviceItem(item, "  ");
                            }
                        }
                        return 0;
                    });
                }

                if (command == "list-blocks")
                {
                    return WithProject(projectFile, false, options, delegate(Project project)
                    {
                        foreach (PlcTarget plc in SelectPlcs(project, options))
                        {
                            Console.WriteLine("# PLC\t{0}\t{1}\t{2}", plc.DeviceName, plc.ItemPath, plc.Software.Name);
                            Console.WriteLine("Name\tType\tNumber\tLanguage\tGroup\tConsistent\tKnowHowProtected");
                            List<BlockRecord> blocks = ListBlocks(plc.Software);
                            foreach (BlockRecord block in blocks)
                            {
                                Console.WriteLine("{0}\t{1}\t{2}\t{3}\t{4}\t{5}\t{6}",
                                    block.Block.Name,
                                    block.Block.GetType().Name,
                                    SafeRead(delegate { return block.Block.Number.ToString(); }, ""),
                                    SafeRead(delegate { return block.Block.ProgrammingLanguage.ToString(); }, ""),
                                    block.GroupPath,
                                    SafeRead(delegate { return block.Block.IsConsistent.ToString(); }, ""),
                                    SafeRead(delegate { return block.Block.IsKnowHowProtected.ToString(); }, ""));
                            }
                        }
                        return 0;
                    });
                }

                if (command == "list-hmi")
                {
                    return WithProject(projectFile, false, options, delegate(Project project)
                    {
                        List<HmiTargetRecord> targets = FindHmiTargets(project);
                        Console.WriteLine("Device\tItemPath\tFlavor\tSoftware");
                        foreach (HmiTargetRecord target in targets)
                        {
                            Console.WriteLine("{0}\t{1}\t{2}\t{3}",
                                target.DeviceName,
                                target.ItemPath,
                                target.Flavor,
                                HmiSoftwareName(target.Software));
                        }
                        Console.WriteLine("SUMMARY\tHmiTargets\t{0}", targets.Count);
                        return 0;
                    });
                }

                if (command == "read-hmi")
                {
                    return WithProject(projectFile, false, options, delegate(Project project)
                    {
                        return ReadHmiProject(projectFile, project, options);
                    });
                }

                if (command == "import-hmi")
                {
                    return WithProject(projectFile, true, options, delegate(Project project)
                    {
                        return ImportHmiArtifacts(projectFile, project, options);
                    });
                }

                if (command == "apply-hmi-manifest")
                {
                    return WithProject(projectFile, true, options, delegate(Project project)
                    {
                        return ApplyHmiManifest(projectFile, project, options);
                    });
                }

                if (command == "export-blocks")
                {
                    return WithProject(projectFile, false, options, delegate(Project project)
                    {
                        string output = GetOption(options, "--output", DefaultExportDir(projectFile));
                        string blockName = GetOption(options, "--block", "");
                        string language = GetOption(options, "--language", "");
                        bool includeInconsistent = HasFlag(options, "--include-inconsistent");
                        Directory.CreateDirectory(output);

                        int count = 0;
                        int failed = 0;
                        int skipped = 0;
                        foreach (PlcTarget plc in SelectPlcs(project, options))
                        {
                            foreach (BlockRecord record in ListBlocks(plc.Software))
                            {
                                if (blockName.Length > 0 && !record.Block.Name.Equals(blockName, StringComparison.OrdinalIgnoreCase)) continue;
                                if (language.Length > 0 && !SafeRead(delegate { return record.Block.ProgrammingLanguage.ToString(); }, "").Equals(language, StringComparison.OrdinalIgnoreCase)) continue;
                                if (!includeInconsistent && !SafeReadBool(delegate { return record.Block.IsConsistent; }, true))
                                {
                                    Console.WriteLine("SKIPPED\t{0}\tInconsistent block. Compile/fix it or add --include-inconsistent to attempt export.", record.Block.Name);
                                    skipped++;
                                    continue;
                                }

                                string fileName = MakeSafeFileName(plc.DeviceName + "_" + record.Block.Name + ".xml");
                                string filePath = Path.Combine(output, fileName);
                                try
                                {
                                    record.Block.Export(new FileInfo(filePath), ExportOptions.WithDefaults);
                                    Console.WriteLine("EXPORTED\t{0}\t{1}", record.Block.Name, filePath);
                                    count++;
                                }
                                catch (Exception ex)
                                {
                                    Console.WriteLine("EXPORT_FAILED\t{0}\t{1}", record.Block.Name, ex.Message.Replace(Environment.NewLine, " "));
                                    failed++;
                                }
                            }
                        }
                        Console.WriteLine("SUMMARY\tExportedBlocks\t{0}", count);
                        Console.WriteLine("SUMMARY\tSkippedBlocks\t{0}", skipped);
                        Console.WriteLine("SUMMARY\tFailedBlocks\t{0}", failed);
                        return count > 0 ? 0 : 1;
                    });
                }

                if (command == "import-blocks")
                {
                    return WithProject(projectFile, true, options, delegate(Project project)
                    {
                        string input = GetRequired(options, "--input");
                        bool apply = HasFlag(options, "--apply");
                        bool noSave = HasFlag(options, "--no-save");
                        string groupPath = GetOption(options, "--group", "");
                        List<string> files = ResolveXmlFiles(input);
                        List<PlcTarget> plcs = SelectPlcs(project, options);
                        if (plcs.Count != 1) throw new InvalidOperationException("Import requires exactly one PLC. Use --plc when the project has multiple PLCs.");

                        PlcTarget plc = plcs[0];
                        Console.WriteLine("PLAN\tPLC\t{0}\t{1}\t{2}", plc.DeviceName, plc.ItemPath, plc.Software.Name);
                        Console.WriteLine("PLAN\tGroup\t{0}", groupPath.Length == 0 ? "<root>" : groupPath);
                        Console.WriteLine("PLAN\tApply\t{0}", apply);
                        foreach (string file in files)
                        {
                            Console.WriteLine("PLAN_IMPORT\t{0}", file);
                        }

                        if (!apply)
                        {
                            Console.WriteLine("DRY_RUN\tNo project changes were made. Add --apply to import.");
                            return 0;
                        }

                        int imported = 0;
                        PlcBlockUserGroup userGroup = null;
                        if (groupPath.Length > 0) userGroup = ResolveUserGroup(plc.Software.BlockGroup, groupPath);
                        SWImportOptions swOptions = SWImportOptions.IgnoreMissingReferencedObjects | SWImportOptions.IgnoreStructuralChanges | SWImportOptions.IgnoreUnitAttributes;

                        foreach (string file in files)
                        {
                            IList<PlcBlock> importedBlocks = userGroup == null
                                ? plc.Software.BlockGroup.Blocks.Import(new FileInfo(file), ImportOptions.Override, swOptions)
                                : userGroup.Blocks.Import(new FileInfo(file), ImportOptions.Override, swOptions);
                            foreach (PlcBlock block in importedBlocks)
                            {
                                Console.WriteLine("IMPORTED\t{0}\t{1}", block.Name, file);
                                imported++;
                            }
                        }

                        if (!noSave)
                        {
                            project.Save();
                            Console.WriteLine("SAVED\t{0}", project.Path.FullName);
                        }
                        else
                        {
                            Console.WriteLine("NOT_SAVED\tProject changes remain unsaved in the TIA session.");
                        }
                        Console.WriteLine("SUMMARY\tImportedBlocks\t{0}", imported);
                        return 0;
                    });
                }

                if (command == "compile-plc")
                {
                    return WithProject(projectFile, false, options, delegate(Project project)
                    {
                        bool saveAfterCompile = HasFlag(options, "--save");
                        int worst = 0;
                        foreach (PlcTarget plc in SelectPlcs(project, options))
                        {
                            ICompilable compilable = plc.Software.GetService<ICompilable>();
                            if (compilable == null)
                            {
                                Console.WriteLine("COMPILE_SKIPPED\t{0}\tNo ICompilable service", plc.Software.Name);
                                continue;
                            }
                            CompilerResult result = compilable.Compile();
                            Console.WriteLine("COMPILE\t{0}\tState={1}\tErrors={2}\tWarnings={3}", plc.Software.Name, result.State, result.ErrorCount, result.WarningCount);
                            PrintCompilerMessages(result.Messages, "");
                            if (result.State == CompilerResultState.Error || result.ErrorCount > 0) worst = 2;
                            else if (result.State == CompilerResultState.Warning || result.WarningCount > 0) worst = Math.Max(worst, 1);
                        }
                        if (saveAfterCompile && worst < 2)
                        {
                            project.Save();
                            Console.WriteLine("SAVED\t{0}", project.Path.FullName);
                        }
                        return worst;
                    });
                }

                if (command == "import-sources")
                {
                    return WithProject(projectFile, true, options, delegate(Project project)
                    {
                        List<PlcTarget> plcs = SelectPlcs(project, options);
                        if (plcs.Count != 1) throw new InvalidOperationException("Source import requires exactly one PLC. Use --plc when the project has multiple PLCs.");

                        PlcTarget plc = plcs[0];
                        string sourceDir = GetRequired(options, "--source-dir");
                        bool compile = HasFlag(options, "--compile");
                        bool save = HasFlag(options, "--save") || compile;

                        ImportSources(project, plc.Software, sourceDir);

                        int compileResult = 0;
                        if (compile)
                        {
                            Dictionary<string, string> compileOptions = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
                            compileOptions["--plc"] = plc.Software.Name;
                            if (save)
                            {
                                compileOptions["--save"] = "true";
                            }
                            compileResult = CompileSelectedPlcs(project, compileOptions, save);
                        }
                        else if (save)
                        {
                            project.Save();
                            Console.WriteLine("SAVED\t{0}", project.Path.FullName);
                        }

                        return compileResult;
                    });
                }

                throw new InvalidOperationException("Unknown command: " + command);
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine("ERROR\t{0}", ex.Message);
                PrintException(ex, "");
                return 1;
            }
        }

        private static int CompileSelectedPlcs(Project project, Dictionary<string, string> options, bool save)
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
                PrintCompilerMessages(result.Messages, "  ");

                if (result.State == CompilerResultState.Error || result.ErrorCount > 0)
                {
                    worst = 2;
                }
                else if (result.State == CompilerResultState.Warning || result.WarningCount > 0)
                {
                    worst = Math.Max(worst, 1);
                }
            }

            if (save && worst < 2)
            {
                project.Save();
                Console.WriteLine("SAVED\t{0}", project.Path.FullName);
            }

            return worst;
        }

        private static void ImportSources(Project project, PlcSoftware plcSoftware, string sourceDir)
        {
            DirectoryInfo dir = new DirectoryInfo(Path.GetFullPath(sourceDir));
            if (!dir.Exists)
            {
                throw new DirectoryNotFoundException(dir.FullName);
            }

            List<FileInfo> structuralFiles = new List<FileInfo>();
            structuralFiles.AddRange(OrderNamedStructureFiles(new List<FileInfo>(dir.GetFiles("*.udt", SearchOption.TopDirectoryOnly))));
            structuralFiles.AddRange(OrderNamedStructureFiles(new List<FileInfo>(dir.GetFiles("*.scl", SearchOption.TopDirectoryOnly))));
            structuralFiles.AddRange(OrderNamedStructureFiles(new List<FileInfo>(dir.GetFiles("*.awl", SearchOption.TopDirectoryOnly))));

            List<FileInfo> globalDbFiles = new List<FileInfo>();
            List<FileInfo> instanceDbFiles = new List<FileInfo>();
            foreach (FileInfo dbFile in SortFilesByName(dir.GetFiles("*.db", SearchOption.TopDirectoryOnly)))
            {
                if (IsInstanceDbSource(dbFile))
                {
                    instanceDbFiles.Add(dbFile);
                }
                else
                {
                    globalDbFiles.Add(dbFile);
                }
            }

            List<FileInfo> files = new List<FileInfo>();
            files.AddRange(structuralFiles);
            files.AddRange(globalDbFiles);
            files.AddRange(instanceDbFiles);
            bool hasFollowOnDbSources = globalDbFiles.Count > 0 || instanceDbFiles.Count > 0;

            if (files.Count == 0)
            {
                throw new InvalidOperationException("No source files were found in " + dir.FullName);
            }

            List<PlcExternalSource> addedSources = new List<PlcExternalSource>();
            foreach (FileInfo file in files)
            {
                PlcExternalSource existing = plcSoftware.ExternalSourceGroup.ExternalSources.Find(file.Name);
                if (existing != null)
                {
                    existing.Delete();
                    Console.WriteLine("DELETED_SOURCE\t{0}", file.Name);
                }

                PlcExternalSource source = plcSoftware.ExternalSourceGroup.ExternalSources.CreateFromFile(file.Name, file.FullName);
                addedSources.Add(source);
                Console.WriteLine("ADDED_SOURCE\t{0}\t{1}", file.Name, file.FullName);
            }

            HashSet<string> structuralNames = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (FileInfo file in structuralFiles)
            {
                structuralNames.Add(file.Name);
            }

            foreach (PlcExternalSource source in addedSources)
            {
                if (structuralNames.Contains(source.Name))
                {
                    WriteGeneratedObjects(source);
                }
            }

            if (structuralNames.Count > 0)
            {
                project.Save();
                Console.WriteLine("SAVED_PHASE\tStructuralSources\t{0}", project.Path.FullName);
                if (hasFollowOnDbSources)
                {
                    Console.WriteLine("COMPILE_PHASE_SKIPPED\tStructuralSources\tReason=DBSourcesPending");
                }
                else
                {
                    ICompilable compilable = plcSoftware.GetService<ICompilable>();
                    if (compilable != null)
                    {
                        CompilerResult phaseResult = compilable.Compile();
                        Console.WriteLine("COMPILE_PHASE\tStructuralSources\tState={0}\tErrors={1}\tWarnings={2}",
                            phaseResult.State,
                            phaseResult.ErrorCount,
                            phaseResult.WarningCount);
                        PrintCompilerMessages(phaseResult.Messages, "  ");
                    }
                }
            }

            foreach (PlcExternalSource source in addedSources)
            {
                if (!structuralNames.Contains(source.Name))
                {
                    WriteGeneratedObjects(source);
                }
            }
        }

        private static List<FileInfo> SortFilesByName(FileInfo[] files)
        {
            List<FileInfo> sorted = new List<FileInfo>(files);
            sorted.Sort(delegate(FileInfo left, FileInfo right)
            {
                return string.Compare(left.Name, right.Name, StringComparison.OrdinalIgnoreCase);
            });
            return sorted;
        }

        private static List<FileInfo> OrderNamedStructureFiles(List<FileInfo> files)
        {
            List<FileInfo> remaining = new List<FileInfo>(files);
            remaining.Sort(delegate(FileInfo left, FileInfo right)
            {
                return string.Compare(left.Name, right.Name, StringComparison.OrdinalIgnoreCase);
            });

            Dictionary<string, FileInfo> byDeclaredName = new Dictionary<string, FileInfo>(StringComparer.OrdinalIgnoreCase);
            Dictionary<FileInfo, HashSet<string>> declaredNamesByFile = new Dictionary<FileInfo, HashSet<string>>();
            foreach (FileInfo file in remaining)
            {
                HashSet<string> declaredNames = GetDeclaredObjectNames(file);
                declaredNamesByFile[file] = declaredNames;
                foreach (string declaredName in declaredNames)
                {
                    if (!byDeclaredName.ContainsKey(declaredName))
                    {
                        byDeclaredName.Add(declaredName, file);
                    }
                }
            }

            Dictionary<FileInfo, HashSet<string>> dependencyMap = new Dictionary<FileInfo, HashSet<string>>();
            foreach (FileInfo file in remaining)
            {
                dependencyMap[file] = GetReferencedKnownObjects(file, byDeclaredName, declaredNamesByFile[file]);
            }

            List<FileInfo> ordered = new List<FileInfo>();
            HashSet<string> resolvedNames = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

            while (remaining.Count > 0)
            {
                FileInfo next = null;
                foreach (FileInfo candidate in remaining)
                {
                    bool ready = true;
                    foreach (string dependency in dependencyMap[candidate])
                    {
                        if (!resolvedNames.Contains(dependency))
                        {
                            ready = false;
                            break;
                        }
                    }

                    if (ready)
                    {
                        next = candidate;
                        break;
                    }
                }

                if (next == null)
                {
                    ordered.AddRange(remaining);
                    break;
                }

                ordered.Add(next);
                foreach (string declaredName in declaredNamesByFile[next])
                {
                    resolvedNames.Add(declaredName);
                }
                remaining.Remove(next);
            }

            return ordered;
        }

        private static HashSet<string> GetDeclaredObjectNames(FileInfo file)
        {
            HashSet<string> declared = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (string line in File.ReadAllLines(file.FullName))
            {
                Match match = Regex.Match(line, "^\\s*(TYPE|FUNCTION_BLOCK|FUNCTION|ORGANIZATION_BLOCK)\\s+\"([^\"]+)\"", RegexOptions.IgnoreCase);
                if (match.Success)
                {
                    declared.Add(match.Groups[2].Value.Trim());
                }
            }

            return declared;
        }

        private static HashSet<string> GetReferencedKnownObjects(FileInfo file, Dictionary<string, FileInfo> knownObjectFiles, HashSet<string> selfDeclaredNames)
        {
            HashSet<string> references = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (string line in File.ReadAllLines(file.FullName))
            {
                foreach (Match match in Regex.Matches(line, "\"([^\"]+)\""))
                {
                    string candidate = match.Groups[1].Value.Trim();
                    if (candidate.Length == 0)
                    {
                        continue;
                    }

                    if (selfDeclaredNames.Contains(candidate))
                    {
                        continue;
                    }

                    if (knownObjectFiles.ContainsKey(candidate))
                    {
                        references.Add(candidate);
                    }
                }
            }

            return references;
        }

        private static bool IsInstanceDbSource(FileInfo file)
        {
            foreach (string line in File.ReadAllLines(file.FullName))
            {
                string trimmed = line.Trim();
                if (trimmed.Length == 0)
                {
                    continue;
                }

                if (trimmed.StartsWith("\"", StringComparison.Ordinal) &&
                    trimmed.EndsWith("\"", StringComparison.Ordinal) &&
                    trimmed.Length > 2)
                {
                    return true;
                }

                if (string.Equals(trimmed, "IEC_TIMER", StringComparison.OrdinalIgnoreCase))
                {
                    return true;
                }
            }

            return false;
        }

        private static void WriteGeneratedObjects(PlcExternalSource source)
        {
            IList<IEngineeringObject> generated = source.GenerateBlocksFromSource(GenerateBlockOption.None);
            Console.WriteLine("GENERATED_FROM_SOURCE\t{0}\tCount={1}", source.Name, generated.Count);
            foreach (IEngineeringObject item in generated)
            {
                Console.WriteLine("GENERATED_OBJECT\t{0}", item.GetType().FullName);
            }
        }

        private static void PrintException(Exception ex, string indent)
        {
            if (ex == null) return;
            Console.Error.WriteLine("{0}{1}: {2}", indent, ex.GetType().FullName, ex.Message);
            if (!string.IsNullOrEmpty(ex.StackTrace)) Console.Error.WriteLine("{0}{1}", indent, ex.StackTrace);
            PrintException(ex.InnerException, indent + "  ");
        }

        private static int WithProject(FileInfo projectFile, bool writeIntent, Dictionary<string, string> options, Func<Project, int> action)
        {
            TiaPortal tia = null;
            Project project = null;
            bool closeProject = true;
            try
            {
                bool attach = HasFlag(options, "--attach");
                bool ui = HasFlag(options, "--ui");

                if (attach)
                {
                    Console.WriteLine("ATTACHING\tSearching running TIA Portal sessions");
                    Console.Out.Flush();
                    tia = AttachToRunningPortal(projectFile);
                    closeProject = false;
                }
                else
                {
                    TiaPortalMode mode = ui ? TiaPortalMode.WithUserInterface : TiaPortalMode.WithoutUserInterface;
                    Console.WriteLine("STARTING\tTIA Portal\tMode={0}", mode);
                    Console.Out.Flush();
                    tia = new TiaPortal(mode);
                }

                project = FindOpenProject(tia, projectFile);
                if (project == null)
                {
                    Console.WriteLine("OPENING\t{0}", projectFile.FullName);
                    Console.Out.Flush();
                    project = tia.Projects.Open(projectFile);
                    closeProject = true;
                }
                Console.WriteLine("OPENED\t{0}\tWriteIntent={1}", projectFile.FullName, writeIntent);
                Console.Out.Flush();
                return action(project);
            }
            finally
            {
                if (project != null && closeProject) project.Close();
                if (tia != null) tia.Dispose();
            }
        }

        private static TiaPortal AttachToRunningPortal(FileInfo projectFile)
        {
            IList<TiaPortalProcess> processes = TiaPortal.GetProcesses();
            if (processes == null || processes.Count == 0) throw new InvalidOperationException("No running TIA Portal process found for --attach.");

            TiaPortalProcess fallback = null;
            foreach (TiaPortalProcess process in processes)
            {
                Console.WriteLine("ATTACH_CANDIDATE\tId={0}\tMode={1}\tProject={2}", process.Id, process.Mode, process.ProjectPath == null ? "" : process.ProjectPath.FullName);
                if (fallback == null) fallback = process;
                if (process.ProjectPath != null && PathsEqual(process.ProjectPath.FullName, projectFile.FullName))
                {
                    return process.Attach();
                }
            }
            return fallback.Attach();
        }

        private static Project FindOpenProject(TiaPortal tia, FileInfo projectFile)
        {
            foreach (Project openProject in tia.Projects)
            {
                if (openProject.Path != null && PathsEqual(openProject.Path.FullName, projectFile.FullName))
                {
                    return openProject;
                }
            }
            return null;
        }

        private static int CreateProject(Dictionary<string, string> options)
        {
            string projectName = GetRequired(options, "--name");
            string directoryPath = GetOption(options, "--directory", Directory.GetCurrentDirectory());
            string deviceType = GetOption(options, "--device-type", "");
            string deviceItemType = GetOption(options, "--device-item-type", "");
            string itemName = GetOption(options, "--item-name", "PLC_1");
            string deviceName = GetOption(options, "--device-name", "NewDevice");
            bool ui = HasFlag(options, "--ui");

            DirectoryInfo directory = new DirectoryInfo(Path.GetFullPath(directoryPath));
            if (!directory.Exists)
            {
                directory.Create();
            }

            TiaPortalMode mode = ui ? TiaPortalMode.WithUserInterface : TiaPortalMode.WithoutUserInterface;
            Console.WriteLine("STARTING\tTIA Portal\tMode={0}", mode);
            Console.Out.Flush();

            using (TiaPortal tia = new TiaPortal(mode))
            {
                Console.WriteLine("CREATING_PROJECT\t{0}\t{1}", directory.FullName, projectName);
                Console.Out.Flush();

                Project project = tia.Projects.Create(directory, projectName);
                try
                {
                    Console.WriteLine("CREATED_PROJECT\t{0}", project.Path == null ? projectName : project.Path.FullName);

                    if (deviceItemType.Length > 0)
                    {
                        Device device = project.Devices.CreateWithItem(deviceItemType, itemName, deviceName);
                        Console.WriteLine("CREATED_DEVICE\t{0}\t{1}", device.Name, device.TypeIdentifier);
                    }
                    else if (deviceType.Length > 0)
                    {
                        Device device = project.Devices.Create(deviceType, deviceName);
                        Console.WriteLine("CREATED_DEVICE\t{0}\t{1}", device.Name, device.TypeIdentifier);
                    }

                    project.Save();
                    Console.WriteLine("SAVED\t{0}", project.Path == null ? projectName : project.Path.FullName);
                }
                finally
                {
                    project.Close();
                }
            }

            return 0;
        }

        private static int HoldProject(FileInfo projectFile, Dictionary<string, string> options)
        {
            bool ui = HasFlag(options, "--ui");
            string leaseFile = GetOption(options, "--lease-file", "");
            int pollMs = ParseIntOrDefault(GetOption(options, "--poll-ms", "1000"), 1000);
            TiaPortalMode mode = ui ? TiaPortalMode.WithUserInterface : TiaPortalMode.WithoutUserInterface;

            if (leaseFile.Length > 0)
            {
                string leaseDirectory = Path.GetDirectoryName(leaseFile);
                if (!string.IsNullOrEmpty(leaseDirectory))
                {
                    Directory.CreateDirectory(leaseDirectory);
                }
                if (!File.Exists(leaseFile))
                {
                    File.WriteAllText(leaseFile, projectFile.FullName);
                }
            }

            Console.WriteLine("STARTING\tTIA Portal\tMode={0}", mode);
            Console.Out.Flush();

            using (TiaPortal tia = new TiaPortal(mode))
            {
                Console.WriteLine("OPENING\t{0}", projectFile.FullName);
                Console.Out.Flush();

                Project project = tia.Projects.Open(projectFile);
                try
                {
                    Console.WriteLine("OPENED\t{0}\tWriteIntent=False", projectFile.FullName);
                    Console.WriteLine("SESSION_READY\t{0}\tLeaseFile={1}", projectFile.FullName, leaseFile);
                    Console.Out.Flush();

                    if (leaseFile.Length > 0)
                    {
                        while (File.Exists(leaseFile))
                        {
                            Thread.Sleep(pollMs);
                        }
                        Console.WriteLine("SESSION_END_REQUEST\tLease file removed.");
                    }
                    else
                    {
                        Console.WriteLine("SESSION_HOLD\tPress Ctrl+C to exit.");
                        Console.Out.Flush();
                        using (ManualResetEvent stopEvent = new ManualResetEvent(false))
                        {
                            Console.CancelKeyPress += delegate(object sender, ConsoleCancelEventArgs e)
                            {
                                e.Cancel = true;
                                stopEvent.Set();
                            };
                            stopEvent.WaitOne();
                        }
                    }
                }
                finally
                {
                    project.Close();
                }
            }

            return 0;
        }

        private static List<PlcTarget> SelectPlcs(Project project, Dictionary<string, string> options)
        {
            string filter = GetOption(options, "--plc", "");
            List<PlcTarget> all = FindPlcs(project);
            if (filter.Length == 0) return all;

            List<PlcTarget> selected = new List<PlcTarget>();
            foreach (PlcTarget plc in all)
            {
                if (ContainsIgnoreCase(plc.DeviceName, filter) ||
                    ContainsIgnoreCase(plc.ItemPath, filter) ||
                    ContainsIgnoreCase(plc.Software.Name, filter))
                {
                    selected.Add(plc);
                }
            }
            if (selected.Count == 0) throw new InvalidOperationException("No PLC matched --plc " + filter);
            return selected;
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

        private static List<HmiTargetRecord> FindHmiTargets(Project project)
        {
            List<HmiTargetRecord> result = new List<HmiTargetRecord>();
            foreach (Device device in project.Devices)
            {
                foreach (DeviceItem item in device.DeviceItems)
                {
                    WalkHmiDeviceItem(device.Name, item.Name, item, result);
                }
            }
            return result;
        }

        private static void WalkHmiDeviceItem(string deviceName, string path, DeviceItem item, List<HmiTargetRecord> result)
        {
            try
            {
                SoftwareContainer container = item.GetService<SoftwareContainer>();
                if (container != null && container.Software != null)
                {
                    object software = container.Software;
                    string fullName = software.GetType().FullName ?? "";
                    if (fullName.Equals("Siemens.Engineering.Hmi.HmiTarget", StringComparison.Ordinal) ||
                        fullName.Equals("Siemens.Engineering.HmiUnified.HmiSoftware", StringComparison.Ordinal) ||
                        fullName.EndsWith(".HmiTarget", StringComparison.Ordinal) ||
                        fullName.EndsWith(".HmiSoftware", StringComparison.Ordinal))
                    {
                        result.Add(new HmiTargetRecord
                        {
                            DeviceName = deviceName,
                            ItemPath = path,
                            Flavor = fullName.IndexOf("HmiUnified", StringComparison.OrdinalIgnoreCase) >= 0 ? "Unified" : "Classic",
                            Software = software
                        });
                    }
                }
            }
            catch
            {
                // Some hardware items do not expose a software service.
            }

            foreach (DeviceItem child in item.DeviceItems)
            {
                WalkHmiDeviceItem(deviceName, path + "/" + child.Name, child, result);
            }
        }

        private static int ReadHmiProject(FileInfo projectFile, Project project, Dictionary<string, string> options)
        {
            string output = GetOption(options, "--output", Path.Combine(projectFile.Directory.FullName, "PLC_Code", "wincc", "readback", DateTime.Now.ToString("yyyyMMdd_HHmmss")));
            string hmiFilter = GetOption(options, "--hmi", "");
            bool exportArtifacts = !HasFlag(options, "--no-export");
            Directory.CreateDirectory(output);

            List<HmiTargetRecord> targets = FindHmiTargets(project);
            List<HmiTargetRecord> selected = FilterHmis(targets, hmiFilter);
            StringBuilder json = new StringBuilder();
            json.AppendLine("{");
            json.AppendLine("  \"status\": \"ok\",");
            json.AppendLine("  \"project\": \"" + JsonEscape(projectFile.FullName) + "\",");
            json.AppendLine("  \"generatedAt\": \"" + JsonEscape(DateTime.Now.ToString("o")) + "\",");
            json.AppendLine("  \"exportArtifacts\": " + (exportArtifacts ? "true" : "false") + ",");
            json.AppendLine("  \"targets\": [");

            for (int i = 0; i < selected.Count; i++)
            {
                HmiTargetRecord target = selected[i];
                HmiSnapshot snapshot = ReadHmiTarget(target, output, exportArtifacts);
                PrintHmiSnapshot(target, snapshot);
                AppendHmiSnapshotJson(json, target, snapshot, "    ", i == selected.Count - 1);
            }

            json.AppendLine("  ]");
            json.AppendLine("}");

            string reportPath = Path.Combine(output, "wincc-readback.json");
            File.WriteAllText(reportPath, json.ToString(), Encoding.UTF8);
            File.WriteAllText(Path.Combine(output, "README.md"), BuildHmiReadme(projectFile, reportPath, selected.Count, exportArtifacts), Encoding.UTF8);

            Console.WriteLine("REPORT\t{0}", reportPath);
            Console.WriteLine("SUMMARY\tHmiTargets\t{0}", selected.Count);
            Console.WriteLine("SUMMARY\tReadbackDirectory\t{0}", output);
            return 0;
        }

        private static List<HmiTargetRecord> FilterHmis(List<HmiTargetRecord> targets, string filter)
        {
            if (string.IsNullOrWhiteSpace(filter))
            {
                return targets;
            }

            List<HmiTargetRecord> selected = new List<HmiTargetRecord>();
            foreach (HmiTargetRecord target in targets)
            {
                if (ContainsIgnoreCase(target.DeviceName, filter) ||
                    ContainsIgnoreCase(target.ItemPath, filter) ||
                    ContainsIgnoreCase(target.Flavor, filter) ||
                    ContainsIgnoreCase(HmiSoftwareName(target.Software), filter))
                {
                    selected.Add(target);
                }
            }
            if (selected.Count == 0)
            {
                throw new InvalidOperationException("No HMI matched --hmi " + filter);
            }
            return selected;
        }

        private static HmiSnapshot ReadHmiTarget(HmiTargetRecord target, string outputRoot, bool exportArtifacts)
        {
            HmiSnapshot snapshot = new HmiSnapshot();
            string targetRoot = Path.Combine(outputRoot, MakeSafeFileName(target.DeviceName + "_" + target.ItemPath.Replace('/', '_')));
            Directory.CreateDirectory(targetRoot);

            if (target.Flavor == "Classic")
            {
                object screenFolder = GetProperty(target.Software, "ScreenFolder");
                if (screenFolder != null)
                {
                    ReadClassicScreenFolder(screenFolder, "", targetRoot, exportArtifacts, snapshot);
                }

                object tagFolder = GetProperty(target.Software, "TagFolder");
                if (tagFolder != null)
                {
                    ReadClassicTagFolder(tagFolder, "", targetRoot, exportArtifacts, snapshot);
                }

                ReadClassicCollection(GetProperty(target.Software, "Connections"), "Connection", targetRoot, exportArtifacts, snapshot);
            }
            else
            {
                ReadUnifiedScreens(GetProperty(target.Software, "Screens"), snapshot);
                ReadUnifiedTags(GetProperty(target.Software, "Tags"), snapshot);
                ReadUnifiedTagTables(GetProperty(target.Software, "TagTables"), snapshot);
                ReadUnifiedAlarms(GetProperty(target.Software, "DiscreteAlarms"), "DiscreteAlarm", snapshot);
                ReadUnifiedAlarms(GetProperty(target.Software, "AnalogAlarms"), "AnalogAlarm", snapshot);
                ReadUnifiedCollection(GetProperty(target.Software, "Connections"), "Connection", snapshot);
            }

            return snapshot;
        }

        private static void ReadClassicScreenFolder(object folder, string folderPath, string targetRoot, bool exportArtifacts, HmiSnapshot snapshot)
        {
            object screens = GetProperty(folder, "Screens");
            foreach (object screen in Enumerate(screens))
            {
                string name = GetStringProperty(screen, "Name");
                snapshot.Screens.Add(CombinePath(folderPath, name));
                if (exportArtifacts)
                {
                    string output = Path.Combine(targetRoot, "screens", MakeSafeFileName(CombinePath(folderPath, name)) + ".xml");
                    TryExport(screen, output, snapshot.Exports);
                }
            }

            object folders = GetProperty(folder, "Folders");
            foreach (object child in Enumerate(folders))
            {
                ReadClassicScreenFolder(child, CombinePath(folderPath, GetStringProperty(child, "Name")), targetRoot, exportArtifacts, snapshot);
            }
        }

        private static void ReadClassicTagFolder(object folder, string folderPath, string targetRoot, bool exportArtifacts, HmiSnapshot snapshot)
        {
            object tables = GetProperty(folder, "TagTables");
            foreach (object table in Enumerate(tables))
            {
                string tableName = GetStringProperty(table, "Name");
                string qualifiedName = CombinePath(folderPath, tableName);
                snapshot.TagTables.Add(qualifiedName);
                object tags = GetProperty(table, "Tags");
                foreach (object tag in Enumerate(tags))
                {
                    snapshot.Tags.Add(qualifiedName + "/" + GetStringProperty(tag, "Name"));
                }
                if (exportArtifacts)
                {
                    string output = Path.Combine(targetRoot, "tagtables", MakeSafeFileName(qualifiedName) + ".xml");
                    TryExport(table, output, snapshot.Exports);
                }
            }

            object folders = GetProperty(folder, "Folders");
            foreach (object child in Enumerate(folders))
            {
                ReadClassicTagFolder(child, CombinePath(folderPath, GetStringProperty(child, "Name")), targetRoot, exportArtifacts, snapshot);
            }
        }

        private static void ReadClassicCollection(object composition, string kind, string targetRoot, bool exportArtifacts, HmiSnapshot snapshot)
        {
            foreach (object item in Enumerate(composition))
            {
                string name = GetStringProperty(item, "Name");
                if (kind == "Connection")
                {
                    snapshot.Connections.Add(name);
                }
                if (exportArtifacts)
                {
                    string output = Path.Combine(targetRoot, "connections", MakeSafeFileName(name) + ".xml");
                    TryExport(item, output, snapshot.Exports);
                }
            }
        }

        private static void ReadUnifiedScreens(object composition, HmiSnapshot snapshot)
        {
            foreach (object screen in Enumerate(composition))
            {
                string name = GetStringProperty(screen, "Name");
                string details = name + " [" + GetStringProperty(screen, "Width") + "x" + GetStringProperty(screen, "Height") + "]";
                int itemCount = CountUnifiedScreenItems(GetProperty(screen, "ScreenItems"));
                if (itemCount > 0)
                {
                    details += " items=" + itemCount.ToString();
                }
                snapshot.Screens.Add(details);
            }
        }

        private static int CountUnifiedScreenItems(object composition)
        {
            int count = 0;
            foreach (object item in Enumerate(composition))
            {
                count++;
                count += CountUnifiedScreenItems(GetProperty(item, "ScreenItems"));
            }
            return count;
        }

        private static void ReadUnifiedTags(object composition, HmiSnapshot snapshot)
        {
            foreach (object tag in Enumerate(composition))
            {
                string row = GetStringProperty(tag, "Name") +
                    " | table=" + GetStringProperty(tag, "TagTableName") +
                    " | plc=" + GetStringProperty(tag, "PlcName") +
                    " | address=" + GetStringProperty(tag, "PlcTag") +
                    " | type=" + GetStringProperty(tag, "DataType") +
                    " | access=" + GetStringProperty(tag, "AccessMode");
                snapshot.Tags.Add(row);
            }
        }

        private static void ReadUnifiedTagTables(object composition, HmiSnapshot snapshot)
        {
            foreach (object table in Enumerate(composition))
            {
                snapshot.TagTables.Add(GetStringProperty(table, "Name"));
            }
        }

        private static void ReadUnifiedAlarms(object composition, string kind, HmiSnapshot snapshot)
        {
            foreach (object alarm in Enumerate(composition))
            {
                snapshot.Alarms.Add(kind + ":" + GetStringProperty(alarm, "Name"));
            }
        }

        private static void ReadUnifiedCollection(object composition, string kind, HmiSnapshot snapshot)
        {
            foreach (object item in Enumerate(composition))
            {
                if (kind == "Connection")
                {
                    snapshot.Connections.Add(GetStringProperty(item, "Name"));
                }
            }
        }

        private static void PrintHmiSnapshot(HmiTargetRecord target, HmiSnapshot snapshot)
        {
            Console.WriteLine("HMI\t{0}\t{1}\tFlavor={2}", target.DeviceName, target.ItemPath, target.Flavor);
            Console.WriteLine("COUNT\tScreens\t{0}", snapshot.Screens.Count);
            Console.WriteLine("COUNT\tTagTables\t{0}", snapshot.TagTables.Count);
            Console.WriteLine("COUNT\tTags\t{0}", snapshot.Tags.Count);
            Console.WriteLine("COUNT\tAlarms\t{0}", snapshot.Alarms.Count);
            Console.WriteLine("COUNT\tConnections\t{0}", snapshot.Connections.Count);
            foreach (string export in snapshot.Exports)
            {
                Console.WriteLine("EXPORTED_HMI\t{0}", export);
            }
        }

        private static void AppendHmiSnapshotJson(StringBuilder json, HmiTargetRecord target, HmiSnapshot snapshot, string indent, bool last)
        {
            json.AppendLine(indent + "{");
            json.AppendLine(indent + "  \"device\": \"" + JsonEscape(target.DeviceName) + "\",");
            json.AppendLine(indent + "  \"itemPath\": \"" + JsonEscape(target.ItemPath) + "\",");
            json.AppendLine(indent + "  \"flavor\": \"" + JsonEscape(target.Flavor) + "\",");
            json.AppendLine(indent + "  \"software\": \"" + JsonEscape(HmiSoftwareName(target.Software)) + "\",");
            AppendStringArrayJson(json, "screens", snapshot.Screens, indent + "  ", true);
            AppendStringArrayJson(json, "tagTables", snapshot.TagTables, indent + "  ", true);
            AppendStringArrayJson(json, "tags", snapshot.Tags, indent + "  ", true);
            AppendStringArrayJson(json, "alarms", snapshot.Alarms, indent + "  ", true);
            AppendStringArrayJson(json, "connections", snapshot.Connections, indent + "  ", true);
            AppendStringArrayJson(json, "exports", snapshot.Exports, indent + "  ", false);
            json.AppendLine(indent + "}" + (last ? "" : ","));
        }

        private static void AppendStringArrayJson(StringBuilder json, string name, List<string> values, string indent, bool comma)
        {
            json.AppendLine(indent + "\"" + name + "\": [");
            for (int i = 0; i < values.Count; i++)
            {
                json.Append(indent + "  \"" + JsonEscape(values[i]) + "\"");
                json.AppendLine(i == values.Count - 1 ? "" : ",");
            }
            json.AppendLine(indent + "]" + (comma ? "," : ""));
        }

        private static string BuildHmiReadme(FileInfo projectFile, string reportPath, int targetCount, bool exportArtifacts)
        {
            StringBuilder builder = new StringBuilder();
            builder.AppendLine("# WinCC readback");
            builder.AppendLine();
            builder.AppendLine("- Project: `" + projectFile.FullName + "`");
            builder.AppendLine("- HMI targets: `" + targetCount.ToString() + "`");
            builder.AppendLine("- Export artifacts: `" + exportArtifacts.ToString() + "`");
            builder.AppendLine("- Machine-readable report: `" + reportPath + "`");
            builder.AppendLine();
            builder.AppendLine("This report was produced by the Siemens TIA Portal Openness helper. No PLC download was performed.");
            return builder.ToString();
        }

        private static int ImportHmiArtifacts(FileInfo projectFile, Project project, Dictionary<string, string> options)
        {
            string input = GetRequired(options, "--input");
            string kind = GetOption(options, "--kind", "auto").ToLowerInvariant();
            bool apply = HasFlag(options, "--apply");
            bool noSave = HasFlag(options, "--no-save");
            List<HmiTargetRecord> targets = FilterHmis(FindHmiTargets(project), GetOption(options, "--hmi", ""));
            if (targets.Count != 1)
            {
                throw new InvalidOperationException("HMI import requires exactly one target. Use --hmi to select one.");
            }

            List<string> files = ResolveXmlFiles(input);
            HmiTargetRecord target = targets[0];
            Console.WriteLine("PLAN\tHMI\t{0}\t{1}\tFlavor={2}", target.DeviceName, target.ItemPath, target.Flavor);
            foreach (string file in files)
            {
                Console.WriteLine("PLAN_IMPORT_HMI\t{0}\tKind={1}", file, kind);
            }
            if (!apply)
            {
                Console.WriteLine("DRY_RUN\tNo HMI changes were made. Add --apply on a clone to import.");
                return 0;
            }
            if (target.Flavor != "Classic")
            {
                throw new InvalidOperationException("XML import is currently routed for Classic WinCC. Unified uses apply-hmi-manifest for editable object creation.");
            }

            int imported = 0;
            foreach (string file in files)
            {
                string resolvedKind = kind == "auto" ? DetectHmiXmlKind(file) : kind;
                object composition = ResolveClassicImportComposition(target.Software, resolvedKind);
                object result = InvokeMethod(composition, "Import", new object[] { new FileInfo(file), ImportOptions.Override });
                int count = CountEnumerable(result);
                imported += count;
                Console.WriteLine("IMPORTED_HMI\t{0}\tKind={1}\tObjects={2}", file, resolvedKind, count);
            }

            if (!noSave)
            {
                project.Save();
                Console.WriteLine("SAVED\t{0}", projectFile.FullName);
            }
            Console.WriteLine("SUMMARY\tImportedHmiObjects\t{0}", imported);
            return 0;
        }

        private static string DetectHmiXmlKind(string path)
        {
            string text = File.ReadAllText(path, Encoding.UTF8);
            if (text.IndexOf("TagTable", StringComparison.OrdinalIgnoreCase) >= 0 ||
                text.IndexOf("HmiTag", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                return "tagtable";
            }
            if (text.IndexOf("Connection", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                return "connection";
            }
            return "screen";
        }

        private static object ResolveClassicImportComposition(object software, string kind)
        {
            switch (kind)
            {
                case "tag":
                case "tagtable":
                    return GetProperty(GetProperty(software, "TagFolder"), "TagTables");
                case "connection":
                case "connections":
                    return GetProperty(software, "Connections");
                case "screen":
                case "screens":
                    return GetProperty(GetProperty(software, "ScreenFolder"), "Screens");
                default:
                    throw new InvalidOperationException("Unsupported HMI import kind: " + kind);
            }
        }

        private static int ApplyHmiManifest(FileInfo projectFile, Project project, Dictionary<string, string> options)
        {
            if (!HasFlag(options, "--apply"))
            {
                throw new InvalidOperationException("Manifest apply is guarded. Add --apply and run it on a clone.");
            }

            string tagCsv = GetOption(options, "--tag-csv", "");
            string alarmCsv = GetOption(options, "--alarm-csv", "");
            string screenCsv = GetOption(options, "--screen-csv", "");
            List<HmiTargetRecord> targets = FilterHmis(FindHmiTargets(project), GetOption(options, "--hmi", ""));
            if (targets.Count != 1)
            {
                throw new InvalidOperationException("Manifest apply requires exactly one HMI target. Use --hmi to select one.");
            }
            HmiTargetRecord target = targets[0];
            if (target.Flavor != "Unified")
            {
                throw new InvalidOperationException("Direct CSV manifest creation is supported for WinCC Unified only. For Classic WinCC, export/import reviewed XML with import-hmi.");
            }

            int created = 0;
            int updated = 0;
            int warnings = 0;

            if (!string.IsNullOrWhiteSpace(tagCsv))
            {
                foreach (Dictionary<string, string> row in ReadCsvRows(tagCsv))
                {
                    string tagName = GetRowValue(row, "tag", GetRowValue(row, "objectName", ""));
                    if (string.IsNullOrWhiteSpace(tagName))
                    {
                        continue;
                    }
                    object tags = GetProperty(target.Software, "Tags");
                    object tag = FindByName(tags, tagName);
                    bool isNew = tag == null;
                    if (isNew)
                    {
                        tag = InvokeCreate(tags, tagName);
                        created++;
                    }
                    else
                    {
                        updated++;
                    }
                    TrySetProperty(tag, "Name", tagName, ref warnings);
                    TrySetProperty(tag, "PlcTag", tagName, ref warnings);
                    string connection = GetRowValue(row, "connection", "");
                    if (!string.IsNullOrWhiteSpace(connection))
                    {
                        TrySetProperty(tag, "Connection", connection, ref warnings);
                    }
                    Console.WriteLine("{0}_HMI_TAG\t{1}", isNew ? "CREATED" : "UPDATED", tagName);
                }
            }

            if (!string.IsNullOrWhiteSpace(screenCsv))
            {
                foreach (Dictionary<string, string> row in ReadCsvRows(screenCsv))
                {
                    string screenName = GetRowValue(row, "screenName", GetRowValue(row, "name", ""));
                    if (string.IsNullOrWhiteSpace(screenName))
                    {
                        continue;
                    }
                    object screens = GetProperty(target.Software, "Screens");
                    object screen = FindByName(screens, screenName);
                    bool isNew = screen == null;
                    if (isNew)
                    {
                        screen = InvokeCreate(screens, screenName);
                        created++;
                    }
                    else
                    {
                        updated++;
                    }
                    TrySetProperty(screen, "Name", screenName, ref warnings);
                    TrySetProperty(screen, "Width", UInt32Value(GetRowValue(row, "width", "1280")), ref warnings);
                    TrySetProperty(screen, "Height", UInt32Value(GetRowValue(row, "height", "800")), ref warnings);
                    Console.WriteLine("{0}_HMI_SCREEN\t{1}", isNew ? "CREATED" : "UPDATED", screenName);
                }
            }

            if (!string.IsNullOrWhiteSpace(alarmCsv))
            {
                foreach (Dictionary<string, string> row in ReadCsvRows(alarmCsv))
                {
                    string alarmName = GetRowValue(row, "alarmName", GetRowValue(row, "name", ""));
                    if (string.IsNullOrWhiteSpace(alarmName))
                    {
                        continue;
                    }
                    object alarms = GetProperty(target.Software, "DiscreteAlarms");
                    object alarm = FindByName(alarms, alarmName);
                    bool isNew = alarm == null;
                    if (isNew)
                    {
                        alarm = InvokeCreate(alarms, alarmName);
                        created++;
                    }
                    else
                    {
                        updated++;
                    }
                    TrySetProperty(alarm, "Name", alarmName, ref warnings);
                    Console.WriteLine("{0}_HMI_ALARM\t{1}", isNew ? "CREATED" : "UPDATED", alarmName);
                    string trigger = GetRowValue(row, "triggerTag", "");
                    if (!string.IsNullOrWhiteSpace(trigger))
                    {
                        Console.WriteLine("HMI_ALARM_BINDING_REVIEW\t{0}\tTriggerTag={1}", alarmName, trigger);
                    }
                }
            }

            project.Save();
            Console.WriteLine("SAVED\t{0}", projectFile.FullName);
            Console.WriteLine("SUMMARY\tCreatedHmiObjects\t{0}", created);
            Console.WriteLine("SUMMARY\tUpdatedHmiObjects\t{0}", updated);
            Console.WriteLine("SUMMARY\tWarnings\t{0}", warnings);
            return warnings > 0 ? 1 : 0;
        }

        private static List<Dictionary<string, string>> ReadCsvRows(string path)
        {
            if (!File.Exists(path))
            {
                throw new FileNotFoundException("CSV input not found: " + path);
            }
            string[] lines = File.ReadAllLines(path, Encoding.UTF8);
            List<Dictionary<string, string>> rows = new List<Dictionary<string, string>>();
            if (lines.Length == 0)
            {
                return rows;
            }
            List<string> headers = ParseCsvLine(lines[0]);
            for (int i = 1; i < lines.Length; i++)
            {
                if (string.IsNullOrWhiteSpace(lines[i]))
                {
                    continue;
                }
                List<string> values = ParseCsvLine(lines[i]);
                Dictionary<string, string> row = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
                for (int column = 0; column < headers.Count; column++)
                {
                    row[headers[column]] = column < values.Count ? values[column] : "";
                }
                rows.Add(row);
            }
            return rows;
        }

        private static List<string> ParseCsvLine(string line)
        {
            List<string> values = new List<string>();
            StringBuilder value = new StringBuilder();
            bool quoted = false;
            for (int i = 0; i < line.Length; i++)
            {
                char ch = line[i];
                if (ch == '"')
                {
                    if (quoted && i + 1 < line.Length && line[i + 1] == '"')
                    {
                        value.Append('"');
                        i++;
                    }
                    else
                    {
                        quoted = !quoted;
                    }
                }
                else if (ch == ',' && !quoted)
                {
                    values.Add(value.ToString());
                    value.Clear();
                }
                else
                {
                    value.Append(ch);
                }
            }
            values.Add(value.ToString());
            return values;
        }

        private static string GetRowValue(Dictionary<string, string> row, string key, string fallback)
        {
            string value;
            return row.TryGetValue(key, out value) && !string.IsNullOrWhiteSpace(value) ? value.Trim() : fallback;
        }

        private static object UInt32Value(string value)
        {
            uint parsed;
            return uint.TryParse(value, out parsed) ? (object)parsed : (object)(uint)1280;
        }

        private static object FindByName(object composition, string name)
        {
            if (composition == null || string.IsNullOrWhiteSpace(name))
            {
                return null;
            }
            try
            {
                return InvokeMethod(composition, "Find", new object[] { name });
            }
            catch
            {
                return null;
            }
        }

        private static object InvokeCreate(object composition, string name)
        {
            if (composition == null)
            {
                throw new InvalidOperationException("Target HMI composition is not available.");
            }
            return InvokeMethod(composition, "Create", new object[] { name });
        }

        private static void TrySetProperty(object target, string propertyName, object value, ref int warnings)
        {
            try
            {
                if (!SetProperty(target, propertyName, value))
                {
                    warnings++;
                    Console.WriteLine("WARNING\tPropertyUnavailable\t{0}.{1}", target == null ? "<null>" : target.GetType().FullName, propertyName);
                }
            }
            catch (Exception ex)
            {
                warnings++;
                Console.WriteLine("WARNING\tPropertySetFailed\t{0}.{1}\t{2}", target == null ? "<null>" : target.GetType().FullName, propertyName, ex.Message.Replace(Environment.NewLine, " "));
            }
        }

        private static string HmiSoftwareName(object software)
        {
            string name = GetStringProperty(software, "Name");
            return string.IsNullOrWhiteSpace(name) ? Convert.ToString(software) : name;
        }

        private static object GetProperty(object target, string propertyName)
        {
            if (target == null)
            {
                return null;
            }
            PropertyInfo property = target.GetType().GetProperty(propertyName, BindingFlags.Public | BindingFlags.Instance);
            return property == null ? null : property.GetValue(target, null);
        }

        private static bool SetProperty(object target, string propertyName, object value)
        {
            if (target == null)
            {
                return false;
            }
            PropertyInfo property = target.GetType().GetProperty(propertyName, BindingFlags.Public | BindingFlags.Instance);
            if (property == null || !property.CanWrite)
            {
                return false;
            }
            object converted = ConvertValue(value, property.PropertyType);
            property.SetValue(target, converted, null);
            return true;
        }

        private static object ConvertValue(object value, Type targetType)
        {
            if (value == null)
            {
                return null;
            }
            if (targetType.IsInstanceOfType(value))
            {
                return value;
            }
            if (targetType.IsEnum)
            {
                return Enum.Parse(targetType, Convert.ToString(value), true);
            }
            return Convert.ChangeType(value, targetType);
        }

        private static object InvokeMethod(object target, string methodName, object[] arguments)
        {
            if (target == null)
            {
                throw new InvalidOperationException("Cannot invoke " + methodName + " on a null object.");
            }
            MethodInfo[] methods = target.GetType().GetMethods(BindingFlags.Public | BindingFlags.Instance);
            foreach (MethodInfo method in methods)
            {
                if (!method.Name.Equals(methodName, StringComparison.Ordinal) || method.GetParameters().Length != arguments.Length)
                {
                    continue;
                }
                try
                {
                    return method.Invoke(target, arguments);
                }
                catch (TargetInvocationException ex)
                {
                    throw ex.InnerException ?? ex;
                }
                catch
                {
                    // Try the next overload when a provider exposes several signatures.
                }
            }
            throw new MissingMethodException(target.GetType().FullName, methodName);
        }

        private static IEnumerable<object> Enumerate(object value)
        {
            if (value == null)
            {
                yield break;
            }
            IEnumerable enumerable = value as IEnumerable;
            if (enumerable == null)
            {
                yield break;
            }
            foreach (object item in enumerable)
            {
                yield return item;
            }
        }

        private static int CountEnumerable(object value)
        {
            int count = 0;
            foreach (object ignored in Enumerate(value))
            {
                count++;
            }
            return count;
        }

        private static string GetStringProperty(object target, string propertyName)
        {
            object value = GetProperty(target, propertyName);
            return value == null ? "" : Convert.ToString(value);
        }

        private static void TryExport(object target, string path, List<string> exports)
        {
            try
            {
                string directory = Path.GetDirectoryName(path);
                if (!string.IsNullOrWhiteSpace(directory))
                {
                    Directory.CreateDirectory(directory);
                }
                InvokeMethod(target, "Export", new object[] { new FileInfo(path), ExportOptions.WithDefaults });
                exports.Add(path);
            }
            catch (Exception ex)
            {
                Console.WriteLine("EXPORT_HMI_FAILED\t{0}\t{1}", path, ex.Message.Replace(Environment.NewLine, " "));
            }
        }

        private static string JsonEscape(string value)
        {
            if (value == null)
            {
                return "";
            }
            return value.Replace("\\", "\\\\").Replace("\"", "\\\"").Replace("\r", "\\r").Replace("\n", "\\n").Replace("\t", "\\t");
        }

        private static void WalkDeviceItem(string deviceName, string path, DeviceItem item, List<PlcTarget> result)
        {
            try
            {
                SoftwareContainer container = item.GetService<SoftwareContainer>();
                if (container != null)
                {
                    PlcSoftware plc = container.Software as PlcSoftware;
                    if (plc != null)
                    {
                        result.Add(new PlcTarget { DeviceName = deviceName, ItemPath = path, Software = plc });
                    }
                }
            }
            catch
            {
                // Some device items do not expose software services; keep traversal going.
            }

            foreach (DeviceItem child in item.DeviceItems)
            {
                WalkDeviceItem(deviceName, path + "/" + child.Name, child, result);
            }
        }

        private static void PrintDeviceItem(DeviceItem item, string indent)
        {
            Console.WriteLine("{0}{1}\t{2}", indent, item.Name, item.TypeIdentifier);
            foreach (DeviceItem child in item.DeviceItems)
            {
                PrintDeviceItem(child, indent + "  ");
            }
        }

        private static List<BlockRecord> ListBlocks(PlcSoftware software)
        {
            List<BlockRecord> result = new List<BlockRecord>();
            AddBlocks(software.BlockGroup, "", result);
            return result;
        }

        private static void AddBlocks(PlcBlockSystemGroup group, string path, List<BlockRecord> result)
        {
            foreach (PlcBlock block in group.Blocks)
            {
                result.Add(new BlockRecord { GroupPath = path, Block = block });
            }
            foreach (PlcBlockUserGroup child in group.Groups)
            {
                AddBlocks(child, CombinePath(path, child.Name), result);
            }
        }

        private static void AddBlocks(PlcBlockUserGroup group, string path, List<BlockRecord> result)
        {
            foreach (PlcBlock block in group.Blocks)
            {
                result.Add(new BlockRecord { GroupPath = path, Block = block });
            }
            foreach (PlcBlockUserGroup child in group.Groups)
            {
                AddBlocks(child, CombinePath(path, child.Name), result);
            }
        }

        private static PlcBlockUserGroup ResolveUserGroup(PlcBlockSystemGroup root, string groupPath)
        {
            string[] parts = groupPath.Split(new[] { '/', '\\' }, StringSplitOptions.RemoveEmptyEntries);
            PlcBlockUserGroup current = null;
            foreach (string part in parts)
            {
                PlcBlockUserGroup next = null;
                if (current == null)
                {
                    next = root.Groups.Find(part);
                }
                else
                {
                    next = current.Groups.Find(part);
                }
                if (next == null) throw new InvalidOperationException("Block group not found: " + groupPath);
                current = next;
            }
            if (current == null) throw new InvalidOperationException("Group path is empty.");
            return current;
        }

        private static void PrintCompilerMessages(CompilerResultMessageComposition messages, string indent)
        {
            if (messages == null) return;
            foreach (CompilerResultMessage message in messages)
            {
                Console.WriteLine("MESSAGE\t{0}State={1}\tErrors={2}\tWarnings={3}\tPath={4}\tDescription={5}",
                    indent, message.State, message.ErrorCount, message.WarningCount, message.Path, message.Description);
                PrintCompilerMessages(message.Messages, indent + "  ");
            }
        }

        private static FileInfo ResolveProjectFile(string path)
        {
            if (File.Exists(path)) return new FileInfo(path);
            if (!Directory.Exists(path)) throw new DirectoryNotFoundException(path);
            string[] files = Directory.GetFiles(path, "*.ap*", SearchOption.TopDirectoryOnly);
            List<string> supported = new List<string>();
            foreach (string file in files)
            {
                if (Regex.IsMatch(file, @"\.ap(1[6-9]|2[0-1])$", RegexOptions.IgnoreCase))
                {
                    supported.Add(file);
                }
            }

            if (supported.Count == 0) throw new FileNotFoundException("No supported TIA project file (.ap16 through .ap21) found in " + path);
            if (supported.Count > 1) throw new InvalidOperationException("Multiple supported TIA project files found. Pass the exact --project file.");
            return new FileInfo(supported[0]);
        }

        private static List<string> ResolveXmlFiles(string input)
        {
            List<string> files = new List<string>();
            if (File.Exists(input))
            {
                files.Add(Path.GetFullPath(input));
            }
            else if (Directory.Exists(input))
            {
                files.AddRange(Directory.GetFiles(input, "*.xml", SearchOption.TopDirectoryOnly));
            }
            else
            {
                throw new FileNotFoundException("Input path not found: " + input);
            }
            if (files.Count == 0) throw new InvalidOperationException("No XML files found at " + input);
            files.Sort(StringComparer.OrdinalIgnoreCase);
            return files;
        }

        private static string DefaultExportDir(FileInfo projectFile)
        {
            return Path.Combine(projectFile.Directory.FullName, "PLC_Code", "exports", DateTime.Now.ToString("yyyyMMdd_HHmmss"));
        }

        private static string MakeSafeFileName(string value)
        {
            foreach (char c in Path.GetInvalidFileNameChars())
            {
                value = value.Replace(c, '_');
            }
            return value;
        }

        private static string CombinePath(string left, string right)
        {
            return left.Length == 0 ? right : left + "/" + right;
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

        private static bool HasFlag(Dictionary<string, string> options, string key)
        {
            return options.ContainsKey(key);
        }

        private static string GetOption(Dictionary<string, string> options, string key, string defaultValue)
        {
            string value;
            return options.TryGetValue(key, out value) ? value : defaultValue;
        }

        private static string GetRequired(Dictionary<string, string> options, string key)
        {
            string value = GetOption(options, key, "");
            if (value.Length == 0) throw new ArgumentException("Missing required option " + key);
            return value;
        }

        private static bool ContainsIgnoreCase(string value, string search)
        {
            if (value == null) return false;
            return value.IndexOf(search, StringComparison.OrdinalIgnoreCase) >= 0;
        }

        private static bool PathsEqual(string left, string right)
        {
            return string.Equals(Path.GetFullPath(left).TrimEnd('\\'), Path.GetFullPath(right).TrimEnd('\\'), StringComparison.OrdinalIgnoreCase);
        }

        private static int ParseIntOrDefault(string value, int fallback)
        {
            int parsed;
            return int.TryParse(value, out parsed) ? parsed : fallback;
        }

        private delegate string StringReader();

        private static string SafeRead(StringReader reader, string fallback)
        {
            try
            {
                return reader();
            }
            catch
            {
                return fallback;
            }
        }

        private delegate bool BoolReader();

        private static bool SafeReadBool(BoolReader reader, bool fallback)
        {
            try
            {
                return reader();
            }
            catch
            {
                return fallback;
            }
        }

        private static void Usage()
        {
            Console.WriteLine("TIA Portal V16-V21 PLC tool");
            Console.WriteLine("Commands:");
            Console.WriteLine("  create-project --name <projectName> [--directory <dir>] [--device-type <typeIdentifier>] [--device-item-type <typeIdentifier>] [--item-name <name>] [--device-name <name>]");
            Console.WriteLine("  hold-project --project <projectDir|ap16..ap21> [--ui] [--lease-file <path>] [--poll-ms <ms>]");
            Console.WriteLine("  list-devices --project <projectDir|ap16..ap21>");
            Console.WriteLine("  list-plcs --project <projectDir|ap16..ap21>");
            Console.WriteLine("  list-blocks --project <projectDir|ap16..ap21> [--plc <name>]");
            Console.WriteLine("  list-hmi --project <projectDir|ap16..ap21> [--hmi <name>]");
            Console.WriteLine("  read-hmi --project <projectDir|ap16..ap21> [--hmi <name>] [--output <dir>] [--no-export]");
            Console.WriteLine("  import-hmi --project <projectDir|ap16..ap21> --input <xml|dir> [--hmi <name>] [--kind auto|screen|tagtable|connection] [--apply] [--no-save]");
            Console.WriteLine("  apply-hmi-manifest --project <projectDir|ap16..ap21> [--hmi <name>] [--tag-csv <csv>] [--alarm-csv <csv>] [--screen-csv <csv>] [--apply]");
            Console.WriteLine("  export-blocks --project <projectDir|ap16..ap21> [--plc <name>] [--block <name>] [--language LAD|FBD|SCL] [--output <dir>]");
            Console.WriteLine("  import-blocks --project <projectDir|ap16..ap21> --input <xml|dir> [--plc <name>] [--group <path>] [--apply] [--no-save]");
            Console.WriteLine("  compile-plc --project <projectDir|ap16..ap21> [--plc <name>] [--save]");
            Console.WriteLine("  import-sources --project <projectDir|ap16..ap21> [--plc <name>] --source-dir <dir> [--compile] [--save]");
            Console.WriteLine("Common options:");
            Console.WriteLine("  --ui      Start TIA Portal with user interface for projects that need visible prompts.");
            Console.WriteLine("  --attach  Attach to an already running TIA Portal session instead of starting a new one.");
            Console.WriteLine("  --include-inconsistent  For export-blocks, attempt blocks that TIA reports as inconsistent.");
        }
    }

    internal sealed class PlcTarget
    {
        public string DeviceName;
        public string ItemPath;
        public PlcSoftware Software;
    }

    internal sealed class BlockRecord
    {
        public string GroupPath;
        public PlcBlock Block;
    }

    internal sealed class HmiTargetRecord
    {
        public string DeviceName;
        public string ItemPath;
        public string Flavor;
        public object Software;
    }

    internal sealed class HmiSnapshot
    {
        public List<string> Screens = new List<string>();
        public List<string> TagTables = new List<string>();
        public List<string> Tags = new List<string>();
        public List<string> Alarms = new List<string>();
        public List<string> Connections = new List<string>();
        public List<string> Exports = new List<string>();
    }
}
