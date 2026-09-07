using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Text;
using System.Threading;
using System.Windows.Forms;

namespace SiemensTiaSkillSuite
{
    internal static class Program
    {
        [STAThread]
        private static void Main(string[] args)
        {
            string projectPath = "";
            string invokeScript = "";

            for (int i = 0; i < args.Length; i++)
            {
                if (args[i] == "--project" && i + 1 < args.Length)
                {
                    projectPath = args[++i];
                }
                else if (args[i] == "--invoke" && i + 1 < args.Length)
                {
                    invokeScript = args[++i];
                }
            }

            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new MainForm(projectPath, invokeScript));
        }
    }

    internal sealed class MainForm : Form
    {
        private readonly TextBox projectPathBox = new TextBox();
        private readonly TextBox inputXmlBox = new TextBox();
        private readonly TextBox plcNameBox = new TextBox();
        private readonly TreeView projectTree = new TreeView();
        private readonly ListBox runList = new ListBox();
        private readonly RichTextBox previewBox = new RichTextBox();
        private readonly RichTextBox jobBox = new RichTextBox();
        private readonly RichTextBox chatBox = new RichTextBox();
        private readonly TextBox requestBox = new TextBox();
        private readonly Label statusLabel = new Label();
        private readonly System.Windows.Forms.Timer tailTimer = new System.Windows.Forms.Timer();
        private readonly string invokeScript;

        private string projectRoot = "";
        private string currentStdoutPath = "";
        private string currentStderrPath = "";
        private Process currentProcess;

        public MainForm(string projectPath, string invokeScriptArg)
        {
            this.invokeScript = ResolveInvokeScript(invokeScriptArg);
            Text = "Siemens TIA PLC Dev Console";
            Width = 1420;
            Height = 860;
            MinimumSize = new Size(1100, 680);
            Font = new Font("Microsoft YaHei UI", 9F);
            StartPosition = FormStartPosition.CenterScreen;

            BuildUi();
            WireEvents();

            plcNameBox.Text = "PLC_1";
            projectPathBox.Text = projectPath;
            statusLabel.Text = "就绪";

            if (!string.IsNullOrWhiteSpace(projectPath))
            {
                LoadProject(projectPath);
            }
        }

        private static string ResolveInvokeScript(string explicitPath)
        {
            if (!string.IsNullOrWhiteSpace(explicitPath) && File.Exists(explicitPath))
            {
                return Path.GetFullPath(explicitPath);
            }

            string baseDir = AppDomain.CurrentDomain.BaseDirectory;
            string candidate = Path.GetFullPath(Path.Combine(baseDir, "..", "..", "scripts", "invoke-siemens-plc-dev.ps1"));
            if (File.Exists(candidate))
            {
                return candidate;
            }

            candidate = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".codex", "skills", "siemens-tia-plc-dev", "scripts", "invoke-siemens-plc-dev.ps1");
            return candidate;
        }

        private void BuildUi()
        {
            BackColor = Color.FromArgb(242, 239, 229);

            Panel top = new Panel();
            top.Dock = DockStyle.Top;
            top.Height = 72;
            top.Padding = new Padding(12);
            top.BackColor = Color.FromArgb(31, 48, 48);
            Controls.Add(top);

            Label title = new Label();
            title.Text = "Siemens TIA PLC Dev Console";
            title.ForeColor = Color.White;
            title.Font = new Font(Font.FontFamily, 13F, FontStyle.Bold);
            title.AutoSize = true;
            title.Location = new Point(12, 10);
            top.Controls.Add(title);

            Label subtitle = new Label();
            subtitle.Text = "原生窗口版：项目结构、日志、AI任务草稿、Openness工作流";
            subtitle.ForeColor = Color.FromArgb(208, 224, 219);
            subtitle.AutoSize = true;
            subtitle.Location = new Point(14, 40);
            top.Controls.Add(subtitle);

            projectPathBox.Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right;
            projectPathBox.Location = new Point(430, 12);
            projectPathBox.Width = 660;
            top.Controls.Add(projectPathBox);

            Button loadButton = NewButton("加载项目", Color.FromArgb(17, 124, 121));
            loadButton.Anchor = AnchorStyles.Top | AnchorStyles.Right;
            loadButton.Location = new Point(1100, 10);
            loadButton.Width = 96;
            loadButton.Click += delegate { LoadProject(projectPathBox.Text); };
            top.Controls.Add(loadButton);

            statusLabel.Anchor = AnchorStyles.Top | AnchorStyles.Right;
            statusLabel.ForeColor = Color.FromArgb(244, 202, 145);
            statusLabel.AutoSize = true;
            statusLabel.Location = new Point(1210, 18);
            top.Controls.Add(statusLabel);

            SplitContainer outer = new SplitContainer();
            outer.Dock = DockStyle.Fill;
            outer.SplitterWidth = 6;
            outer.SplitterDistance = 350;
            Controls.Add(outer);

            GroupBox leftBox = NewGroup("项目结构");
            leftBox.Dock = DockStyle.Fill;
            outer.Panel1.Controls.Add(leftBox);
            projectTree.Dock = DockStyle.Fill;
            projectTree.HideSelection = false;
            leftBox.Controls.Add(projectTree);

            SplitContainer right = new SplitContainer();
            right.Dock = DockStyle.Fill;
            right.SplitterWidth = 6;
            right.SplitterDistance = 650;
            outer.Panel2.Controls.Add(right);

            GroupBox workflowBox = NewGroup("工作流与日志");
            workflowBox.Dock = DockStyle.Fill;
            right.Panel1.Controls.Add(workflowBox);

            TableLayoutPanel workLayout = new TableLayoutPanel();
            workLayout.Dock = DockStyle.Fill;
            workLayout.RowCount = 5;
            workLayout.ColumnCount = 1;
            workLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 92));
            workLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 74));
            workLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 32));
            workLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 34));
            workLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 34));
            workflowBox.Controls.Add(workLayout);

            FlowLayoutPanel actions = new FlowLayoutPanel();
            actions.Dock = DockStyle.Fill;
            actions.Padding = new Padding(4);
            actions.Controls.Add(CommandButton("Doctor检查", "doctor", Color.FromArgb(31, 48, 48)));
            actions.Controls.Add(CommandButton("快速读取", "read-cycle-skip", Color.FromArgb(17, 124, 121)));
            actions.Controls.Add(CommandButton("完整导出", "read-cycle-full", Color.FromArgb(218, 105, 46)));
            actions.Controls.Add(CommandButton("列程序块", "list-blocks", Color.FromArgb(31, 48, 48)));
            workLayout.Controls.Add(actions, 0, 0);

            TableLayoutPanel writePanel = new TableLayoutPanel();
            writePanel.Dock = DockStyle.Fill;
            writePanel.ColumnCount = 4;
            writePanel.RowCount = 2;
            writePanel.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 74));
            writePanel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            writePanel.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 80));
            writePanel.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 120));
            writePanel.Controls.Add(new Label { Text = "XML", Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleLeft }, 0, 0);
            writePanel.Controls.Add(inputXmlBox, 1, 0);
            writePanel.Controls.Add(new Label { Text = "PLC", Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleCenter }, 2, 0);
            writePanel.Controls.Add(plcNameBox, 3, 0);
            Button writeCycle = NewButton("克隆验证LAD", Color.FromArgb(218, 105, 46));
            writeCycle.Dock = DockStyle.Fill;
            writeCycle.Click += delegate { StartCommand("write-cycle"); };
            writePanel.Controls.Add(writeCycle, 3, 1);
            Button refresh = NewButton("刷新runs", Color.FromArgb(17, 124, 121));
            refresh.Dock = DockStyle.Fill;
            refresh.Click += delegate { RefreshRuns(); };
            writePanel.Controls.Add(refresh, 1, 1);
            workLayout.Controls.Add(writePanel, 0, 1);

            runList.Dock = DockStyle.Fill;
            workLayout.Controls.Add(Wrap("最近 runs", runList), 0, 2);

            previewBox.Dock = DockStyle.Fill;
            previewBox.Font = new Font("Consolas", 9F);
            previewBox.ReadOnly = true;
            previewBox.BackColor = Color.FromArgb(16, 38, 36);
            previewBox.ForeColor = Color.FromArgb(215, 241, 220);
            workLayout.Controls.Add(Wrap("文件/报告预览", previewBox), 0, 3);

            jobBox.Dock = DockStyle.Fill;
            jobBox.Font = new Font("Consolas", 9F);
            jobBox.ReadOnly = true;
            jobBox.BackColor = Color.FromArgb(250, 248, 241);
            workLayout.Controls.Add(Wrap("当前命令输出", jobBox), 0, 4);

            GroupBox aiBox = NewGroup("AI任务草稿");
            aiBox.Dock = DockStyle.Fill;
            right.Panel2.Controls.Add(aiBox);

            TableLayoutPanel aiLayout = new TableLayoutPanel();
            aiLayout.Dock = DockStyle.Fill;
            aiLayout.RowCount = 3;
            aiLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 55));
            aiLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 35));
            aiLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 54));
            aiBox.Controls.Add(aiLayout);

            chatBox.Dock = DockStyle.Fill;
            chatBox.ReadOnly = true;
            chatBox.BackColor = Color.FromArgb(250, 248, 241);
            chatBox.Text = "这里不会偷偷调用云端AI；它会根据项目结构和最近日志生成一份Codex任务草稿，方便回到主对话继续让Codex写PLC程序、改LAD、跑验证。\n";
            aiLayout.Controls.Add(chatBox, 0, 0);

            requestBox.Dock = DockStyle.Fill;
            requestBox.Multiline = true;
            requestBox.ScrollBars = ScrollBars.Vertical;
            requestBox.Text = "例如：把FC5自动流程增加取料超时报警，用LAD写入并在克隆工程中编译验证。";
            aiLayout.Controls.Add(requestBox, 0, 1);

            Button promptButton = NewButton("生成Codex任务草稿", Color.FromArgb(17, 124, 121));
            promptButton.Dock = DockStyle.Fill;
            promptButton.Click += delegate { CreateAiPrompt(); };
            aiLayout.Controls.Add(promptButton, 0, 2);

            tailTimer.Interval = 1200;
            tailTimer.Tick += delegate { RefreshCurrentJobTail(); };
        }

        private void WireEvents()
        {
            projectTree.AfterSelect += delegate
            {
                string path = Convert.ToString(projectTree.SelectedNode.Tag);
                if (!string.IsNullOrWhiteSpace(path) && File.Exists(path))
                {
                    ShowFile(path);
                    if (Path.GetExtension(path).Equals(".xml", StringComparison.OrdinalIgnoreCase))
                    {
                        inputXmlBox.Text = path;
                    }
                }
            };

            runList.DoubleClick += delegate
            {
                RunInfo info = runList.SelectedItem as RunInfo;
                if (info != null)
                {
                    if (File.Exists(info.ReportPath))
                    {
                        ShowFile(info.ReportPath);
                    }
                    else if (Directory.Exists(info.Path))
                    {
                        previewBox.Text = DirectoryListing(info.Path);
                    }
                }
            };
        }

        private static GroupBox NewGroup(string title)
        {
            return new GroupBox { Text = title, Padding = new Padding(8), BackColor = Color.FromArgb(250, 248, 241) };
        }

        private static Control Wrap(string title, Control inner)
        {
            GroupBox box = NewGroup(title);
            box.Dock = DockStyle.Fill;
            inner.Dock = DockStyle.Fill;
            box.Controls.Add(inner);
            return box;
        }

        private static Button NewButton(string text, Color color)
        {
            Button button = new Button();
            button.Text = text;
            button.Height = 34;
            button.FlatStyle = FlatStyle.Flat;
            button.FlatAppearance.BorderSize = 0;
            button.BackColor = color;
            button.ForeColor = Color.White;
            button.Margin = new Padding(5);
            return button;
        }

        private Button CommandButton(string text, string command, Color color)
        {
            Button button = NewButton(text, color);
            button.Width = 132;
            button.Click += delegate { StartCommand(command); };
            return button;
        }

        private void LoadProject(string path)
        {
            try
            {
                string resolved = ResolveProjectRoot(path);
                projectRoot = resolved;
                projectPathBox.Text = resolved;
                statusLabel.Text = "已加载";
                BuildProjectTree();
                RefreshRuns();
                previewBox.Text = "项目已加载：" + resolved + Environment.NewLine + "双击 runs 可查看报告；点击 XML 文件可填入 write-cycle 输入。";
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "加载失败", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private static string ResolveProjectRoot(string path)
        {
            if (string.IsNullOrWhiteSpace(path))
            {
                throw new InvalidOperationException("请先填写项目路径。");
            }
            string full = Path.GetFullPath(path);
            if (File.Exists(full))
            {
                return Path.GetDirectoryName(full);
            }
            if (Directory.Exists(full))
            {
                return full;
            }
            throw new DirectoryNotFoundException("项目路径不存在：" + full);
        }

        private void BuildProjectTree()
        {
            projectTree.BeginUpdate();
            projectTree.Nodes.Clear();
            TreeNode root = new TreeNode(Path.GetFileName(projectRoot));
            root.Tag = projectRoot;
            projectTree.Nodes.Add(root);
            int count = 0;
            AddChildren(root, projectRoot, 0, ref count);
            root.Expand();
            projectTree.EndUpdate();
        }

        private void AddChildren(TreeNode parent, string directory, int depth, ref int count)
        {
            if (depth > 5 || count > 700)
            {
                return;
            }

            string[] skip = new string[] { ".git", "__pycache__", ".session-cache", "bin", "obj" };
            string[] interesting = new string[] { ".ap16", ".ap17", ".ap18", ".ap19", ".ap20", ".ap21", ".xml", ".scl", ".db", ".udt", ".json", ".md", ".txt", ".csv", ".ps1", ".py" };

            foreach (string dir in SafeGetDirectories(directory))
            {
                string name = Path.GetFileName(dir);
                if (Array.IndexOf(skip, name) >= 0)
                {
                    continue;
                }
                TreeNode node = new TreeNode(name);
                node.Tag = dir;
                parent.Nodes.Add(node);
                count++;
                AddChildren(node, dir, depth + 1, ref count);
            }

            foreach (string file in SafeGetFiles(directory))
            {
                string ext = Path.GetExtension(file).ToLowerInvariant();
                if (Array.IndexOf(interesting, ext) < 0)
                {
                    continue;
                }
                TreeNode node = new TreeNode(Path.GetFileName(file));
                node.Tag = file;
                parent.Nodes.Add(node);
                count++;
                if (count > 700)
                {
                    break;
                }
            }
        }

        private static string[] SafeGetDirectories(string path)
        {
            try
            {
                string[] rows = Directory.GetDirectories(path);
                Array.Sort(rows, StringComparer.OrdinalIgnoreCase);
                return rows;
            }
            catch
            {
                return new string[0];
            }
        }

        private static string[] SafeGetFiles(string path)
        {
            try
            {
                string[] rows = Directory.GetFiles(path);
                Array.Sort(rows, StringComparer.OrdinalIgnoreCase);
                return rows;
            }
            catch
            {
                return new string[0];
            }
        }

        private void RefreshRuns()
        {
            runList.Items.Clear();
            if (string.IsNullOrWhiteSpace(projectRoot))
            {
                return;
            }
            string runsRoot = Path.Combine(projectRoot, "PLC_Code", "runs");
            if (!Directory.Exists(runsRoot))
            {
                return;
            }
            List<RunInfo> rows = new List<RunInfo>();
            foreach (string dir in Directory.GetDirectories(runsRoot))
            {
                DirectoryInfo info = new DirectoryInfo(dir);
                rows.Add(new RunInfo
                {
                    Name = info.Name,
                    Path = dir,
                    Modified = info.LastWriteTime,
                    ReportPath = Path.Combine(dir, "workflow-report.json")
                });
            }
            rows.Sort(delegate (RunInfo a, RunInfo b) { return b.Modified.CompareTo(a.Modified); });
            foreach (RunInfo row in rows)
            {
                runList.Items.Add(row);
            }
        }

        private void ShowFile(string path)
        {
            try
            {
                previewBox.Text = ReadText(path);
            }
            catch (Exception ex)
            {
                previewBox.Text = ex.Message;
            }
        }

        private static string DirectoryListing(string path)
        {
            StringBuilder builder = new StringBuilder();
            foreach (string dir in SafeGetDirectories(path))
            {
                builder.AppendLine("[D] " + Path.GetFileName(dir));
            }
            foreach (string file in SafeGetFiles(path))
            {
                builder.AppendLine("[F] " + Path.GetFileName(file));
            }
            return builder.ToString();
        }

        private static string ReadText(string path)
        {
            byte[] bytes = File.ReadAllBytes(path);
            if (bytes.Length > 512 * 1024)
            {
                byte[] shortened = new byte[512 * 1024];
                Array.Copy(bytes, shortened, shortened.Length);
                bytes = shortened;
            }

            Encoding[] encodings = new Encoding[] { new UTF8Encoding(true), Encoding.UTF8, Encoding.GetEncoding("GB18030"), Encoding.Default };
            foreach (Encoding encoding in encodings)
            {
                try
                {
                    return encoding.GetString(bytes);
                }
                catch
                {
                }
            }
            return Encoding.UTF8.GetString(bytes);
        }

        private void StartCommand(string command)
        {
            if (currentProcess != null && !currentProcess.HasExited)
            {
                MessageBox.Show("已有命令正在运行，请等待结束后再启动下一条。", "防止TIA并发冲突", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            try
            {
                string root = ResolveProjectRoot(projectPathBox.Text);
                projectRoot = root;
                Directory.CreateDirectory(Path.Combine(root, "PLC_Code", "console-jobs"));
                List<string> args = BuildCommandArgs(command, root);
                string stamp = DateTime.Now.ToString("yyyyMMdd-HHmmss");
                currentStdoutPath = Path.Combine(root, "PLC_Code", "console-jobs", stamp + "-" + command + ".log");
                currentStderrPath = Path.Combine(root, "PLC_Code", "console-jobs", stamp + "-" + command + ".err.log");
                File.WriteAllText(currentStdoutPath, "", Encoding.UTF8);
                File.WriteAllText(currentStderrPath, "", Encoding.UTF8);

                ProcessStartInfo start = new ProcessStartInfo();
                start.FileName = "powershell.exe";
                start.Arguments = "-NoProfile -ExecutionPolicy Bypass -File " + Quote(invokeScript) + " " + JoinArgs(args);
                start.WorkingDirectory = root;
                start.UseShellExecute = false;
                start.CreateNoWindow = true;
                start.RedirectStandardOutput = true;
                start.RedirectStandardError = true;
                start.StandardOutputEncoding = Encoding.UTF8;
                start.StandardErrorEncoding = Encoding.UTF8;

                currentProcess = new Process();
                currentProcess.StartInfo = start;
                currentProcess.OutputDataReceived += delegate (object sender, DataReceivedEventArgs e) { AppendOutput(currentStdoutPath, e.Data); };
                currentProcess.ErrorDataReceived += delegate (object sender, DataReceivedEventArgs e) { AppendOutput(currentStderrPath, e.Data); };
                currentProcess.EnableRaisingEvents = true;
                currentProcess.Exited += delegate
                {
                    BeginInvoke((Action)delegate
                    {
                        statusLabel.Text = "完成，ExitCode=" + currentProcess.ExitCode;
                        RefreshCurrentJobTail();
                        RefreshRuns();
                    });
                };

                jobBox.Text = "启动命令：" + command + Environment.NewLine + start.Arguments + Environment.NewLine + "日志：" + currentStdoutPath + Environment.NewLine;
                statusLabel.Text = "运行中：" + command;
                currentProcess.Start();
                currentProcess.BeginOutputReadLine();
                currentProcess.BeginErrorReadLine();
                tailTimer.Start();
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "命令启动失败", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private List<string> BuildCommandArgs(string command, string root)
        {
            List<string> args = new List<string>();
            if (command == "doctor")
            {
                args.Add("doctor");
                args.Add("-ProjectPath");
                args.Add(root);
            }
            else if (command == "read-cycle-skip")
            {
                args.AddRange(new string[] { "read-cycle", "-ProjectPath", root, "-Attach", "-SkipExport" });
            }
            else if (command == "read-cycle-full")
            {
                args.AddRange(new string[] { "read-cycle", "-ProjectPath", root, "-Attach" });
            }
            else if (command == "list-blocks")
            {
                args.AddRange(new string[] { "list-blocks", "--project", root, "--plc", PlcName(), "--attach" });
            }
            else if (command == "write-cycle")
            {
                if (string.IsNullOrWhiteSpace(inputXmlBox.Text) || !File.Exists(inputXmlBox.Text))
                {
                    throw new FileNotFoundException("请先选择或填写要验证的LAD XML文件。", inputXmlBox.Text);
                }
                args.AddRange(new string[] { "write-cycle", "-ProjectPath", root, "-InputXml", inputXmlBox.Text, "-PlcName", PlcName(), "-StepTimeoutSeconds", "300" });
            }
            else
            {
                throw new InvalidOperationException("未知命令：" + command);
            }
            return args;
        }

        private string PlcName()
        {
            string text = plcNameBox.Text.Trim();
            return text.Length == 0 ? "PLC_1" : text;
        }

        private static string JoinArgs(List<string> args)
        {
            StringBuilder builder = new StringBuilder();
            for (int i = 0; i < args.Count; i++)
            {
                if (i > 0)
                {
                    builder.Append(" ");
                }
                builder.Append(Quote(args[i]));
            }
            return builder.ToString();
        }

        private static string Quote(string value)
        {
            if (value == null)
            {
                return "\"\"";
            }
            return "\"" + value.Replace("\"", "\\\"") + "\"";
        }

        private void AppendOutput(string path, string line)
        {
            if (line == null)
            {
                return;
            }
            lock (this)
            {
                File.AppendAllText(path, line + Environment.NewLine, Encoding.UTF8);
            }
        }

        private void RefreshCurrentJobTail()
        {
            try
            {
                StringBuilder builder = new StringBuilder();
                if (!string.IsNullOrWhiteSpace(currentStdoutPath) && File.Exists(currentStdoutPath))
                {
                    builder.AppendLine(Tail(ReadText(currentStdoutPath), 20000));
                }
                if (!string.IsNullOrWhiteSpace(currentStderrPath) && File.Exists(currentStderrPath))
                {
                    string err = Tail(ReadText(currentStderrPath), 8000);
                    if (!string.IsNullOrWhiteSpace(err))
                    {
                        builder.AppendLine();
                        builder.AppendLine("[stderr]");
                        builder.AppendLine(err);
                    }
                }
                jobBox.Text = builder.ToString();
                jobBox.SelectionStart = jobBox.TextLength;
                jobBox.ScrollToCaret();
                if (currentProcess == null || currentProcess.HasExited)
                {
                    tailTimer.Stop();
                }
            }
            catch
            {
            }
        }

        private static string Tail(string text, int maxLength)
        {
            if (text == null || text.Length <= maxLength)
            {
                return text ?? "";
            }
            return text.Substring(text.Length - maxLength);
        }

        private void CreateAiPrompt()
        {
            try
            {
                string root = ResolveProjectRoot(projectPathBox.Text);
                string outputDir = Path.Combine(root, "PLC_Code", "ai-prompts");
                Directory.CreateDirectory(outputDir);
                string path = Path.Combine(outputDir, "codex-task-" + DateTime.Now.ToString("yyyyMMdd-HHmmss") + ".md");
                string blockList = FindLatestBlockList(root);
                StringBuilder content = new StringBuilder();
                content.AppendLine("# Codex PLC Task");
                content.AppendLine();
                content.AppendLine("Created: " + DateTime.Now.ToString("s"));
                content.AppendLine("Project: `" + root + "`");
                content.AppendLine();
                content.AppendLine("## User Request");
                content.AppendLine();
                content.AppendLine(requestBox.Text.Trim());
                content.AppendLine();
                content.AppendLine("## Latest Block List");
                content.AppendLine();
                content.AppendLine("```text");
                content.AppendLine(blockList);
                content.AppendLine("```");
                content.AppendLine();
                content.AppendLine("## Suggested Workflow");
                content.AppendLine();
                content.AppendLine("1. Run `read-cycle -Attach -SkipExport` if the project structure is stale.");
                content.AppendLine("2. Edit exported LAD XML, LAD JSON specs, SCL sources, or DB sources.");
                content.AppendLine("3. Use `write-cycle` on a cloned project before applying to the real project.");
                File.WriteAllText(path, content.ToString(), Encoding.UTF8);
                chatBox.AppendText(Environment.NewLine + "已生成任务草稿：" + path + Environment.NewLine);
                previewBox.Text = ReadText(path);
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "生成失败", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private static string FindLatestBlockList(string root)
        {
            string runsRoot = Path.Combine(root, "PLC_Code", "runs");
            if (!Directory.Exists(runsRoot))
            {
                return "";
            }
            List<DirectoryInfo> dirs = new List<DirectoryInfo>();
            foreach (string dir in Directory.GetDirectories(runsRoot))
            {
                dirs.Add(new DirectoryInfo(dir));
            }
            dirs.Sort(delegate (DirectoryInfo a, DirectoryInfo b) { return b.LastWriteTime.CompareTo(a.LastWriteTime); });
            foreach (DirectoryInfo dir in dirs)
            {
                string path = Path.Combine(dir.FullName, "reports", "block-list.txt");
                if (File.Exists(path))
                {
                    return ReadText(path);
                }
            }
            return "";
        }

        private sealed class RunInfo
        {
            public string Name;
            public string Path;
            public string ReportPath;
            public DateTime Modified;

            public override string ToString()
            {
                return Modified.ToString("MM-dd HH:mm:ss") + "  " + Name;
            }
        }
    }
}
