using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
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
        private readonly Label projectBadge = new Label();
        private readonly System.Windows.Forms.Timer tailTimer = new System.Windows.Forms.Timer();
        private readonly string invokeScript;

        private static readonly Color Ink = Color.FromArgb(20, 34, 36);
        private static readonly Color MutedInk = Color.FromArgb(88, 105, 105);
        private static readonly Color Canvas = Color.FromArgb(235, 239, 232);
        private static readonly Color Card = Color.FromArgb(251, 249, 242);
        private static readonly Color CardSoft = Color.FromArgb(243, 246, 239);
        private static readonly Color Rail = Color.FromArgb(16, 44, 46);
        private static readonly Color Teal = Color.FromArgb(8, 128, 124);
        private static readonly Color Orange = Color.FromArgb(224, 111, 45);
        private static readonly Color Gold = Color.FromArgb(242, 190, 93);
        private static readonly Color CodeBack = Color.FromArgb(12, 31, 31);
        private static readonly Color CodeFore = Color.FromArgb(213, 239, 221);

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
            AutoScaleMode = AutoScaleMode.Dpi;
            DoubleBuffered = true;

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
            BackColor = Canvas;

            Panel top = new BannerPanel();
            top.Dock = DockStyle.Top;
            top.Height = 92;
            top.Padding = new Padding(18, 14, 18, 14);
            top.BackColor = Rail;
            Controls.Add(top);

            Label title = new Label();
            title.Text = "Siemens TIA PLC Dev Console";
            title.ForeColor = Color.White;
            title.Font = new Font("Bahnschrift SemiBold", 18F, FontStyle.Bold);
            title.AutoSize = true;
            title.Location = new Point(18, 14);
            title.BackColor = Color.Transparent;
            top.Controls.Add(title);

            Label subtitle = new Label();
            subtitle.Text = "Native PLC engineering cockpit  |  项目结构 · 日志 · AI任务草稿 · Openness工作流";
            subtitle.ForeColor = Color.FromArgb(211, 226, 220);
            subtitle.AutoSize = true;
            subtitle.Location = new Point(21, 52);
            subtitle.BackColor = Color.Transparent;
            top.Controls.Add(subtitle);

            projectPathBox.Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right;
            projectPathBox.Location = new Point(500, 18);
            projectPathBox.Width = 560;
            StyleInput(projectPathBox);
            top.Controls.Add(projectPathBox);

            Button loadButton = NewButton("加载项目", Teal);
            loadButton.Anchor = AnchorStyles.Top | AnchorStyles.Right;
            loadButton.Location = new Point(1074, 15);
            loadButton.Width = 108;
            loadButton.Click += delegate { LoadProject(projectPathBox.Text); };
            top.Controls.Add(loadButton);

            projectBadge.Anchor = AnchorStyles.Top | AnchorStyles.Right;
            projectBadge.Text = "V16-V21";
            projectBadge.ForeColor = Color.FromArgb(28, 45, 42);
            projectBadge.BackColor = Gold;
            projectBadge.Font = new Font(Font.FontFamily, 9F, FontStyle.Bold);
            projectBadge.TextAlign = ContentAlignment.MiddleCenter;
            projectBadge.Location = new Point(1194, 16);
            projectBadge.Size = new Size(82, 28);
            top.Controls.Add(projectBadge);

            statusLabel.Anchor = AnchorStyles.Top | AnchorStyles.Right;
            statusLabel.ForeColor = Color.FromArgb(244, 202, 145);
            statusLabel.AutoSize = true;
            statusLabel.Location = new Point(1290, 22);
            statusLabel.BackColor = Color.Transparent;
            top.Controls.Add(statusLabel);

            SplitContainer outer = new SplitContainer();
            outer.Dock = DockStyle.Fill;
            outer.SplitterWidth = 6;
            outer.SplitterDistance = 360;
            outer.BackColor = Canvas;
            outer.Panel1.Padding = new Padding(12, 14, 6, 14);
            outer.Panel2.Padding = new Padding(6, 14, 12, 14);
            Controls.Add(outer);

            GroupBox leftBox = NewGroup("项目结构");
            leftBox.Dock = DockStyle.Fill;
            outer.Panel1.Controls.Add(leftBox);
            projectTree.Dock = DockStyle.Fill;
            projectTree.HideSelection = false;
            projectTree.BorderStyle = BorderStyle.None;
            projectTree.BackColor = Card;
            projectTree.ForeColor = Ink;
            projectTree.LineColor = Color.FromArgb(174, 190, 184);
            projectTree.Font = new Font("Microsoft YaHei UI", 9.4F);
            projectTree.ItemHeight = 24;
            leftBox.Controls.Add(projectTree);

            SplitContainer right = new SplitContainer();
            right.Dock = DockStyle.Fill;
            right.SplitterWidth = 6;
            right.SplitterDistance = 680;
            right.BackColor = Canvas;
            right.Panel1.Padding = new Padding(0, 0, 6, 0);
            right.Panel2.Padding = new Padding(6, 0, 0, 0);
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
            actions.Padding = new Padding(8, 8, 8, 4);
            actions.BackColor = Card;
            actions.Controls.Add(CommandButton("Doctor 检查", "doctor", Ink));
            actions.Controls.Add(CommandButton("快速读取", "read-cycle-skip", Teal));
            actions.Controls.Add(CommandButton("完整导出", "read-cycle-full", Orange));
            actions.Controls.Add(CommandButton("列程序块", "list-blocks", Ink));
            workLayout.Controls.Add(actions, 0, 0);

            TableLayoutPanel writePanel = new TableLayoutPanel();
            writePanel.Dock = DockStyle.Fill;
            writePanel.ColumnCount = 4;
            writePanel.RowCount = 2;
            writePanel.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 74));
            writePanel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            writePanel.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 80));
            writePanel.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 120));
            writePanel.Padding = new Padding(8, 2, 8, 4);
            writePanel.BackColor = Card;
            StyleInput(inputXmlBox);
            StyleInput(plcNameBox);
            writePanel.Controls.Add(new Label { Text = "LAD XML", Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleLeft, ForeColor = MutedInk }, 0, 0);
            writePanel.Controls.Add(inputXmlBox, 1, 0);
            writePanel.Controls.Add(new Label { Text = "PLC", Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleCenter, ForeColor = MutedInk }, 2, 0);
            writePanel.Controls.Add(plcNameBox, 3, 0);
            Button writeCycle = NewButton("克隆验证 LAD", Orange);
            writeCycle.Dock = DockStyle.Fill;
            writeCycle.Click += delegate { StartCommand("write-cycle"); };
            writePanel.Controls.Add(writeCycle, 3, 1);
            Button refresh = NewButton("刷新 runs", Teal);
            refresh.Dock = DockStyle.Fill;
            refresh.Click += delegate { RefreshRuns(); };
            writePanel.Controls.Add(refresh, 1, 1);
            workLayout.Controls.Add(writePanel, 0, 1);

            runList.Dock = DockStyle.Fill;
            runList.BorderStyle = BorderStyle.None;
            runList.BackColor = CardSoft;
            runList.ForeColor = Ink;
            runList.Font = new Font("Cascadia Mono", 9F);
            runList.ItemHeight = 22;
            workLayout.Controls.Add(Wrap("最近 runs", runList), 0, 2);

            previewBox.Dock = DockStyle.Fill;
            previewBox.Font = new Font("Cascadia Code", 9F);
            previewBox.ReadOnly = true;
            previewBox.BorderStyle = BorderStyle.None;
            previewBox.BackColor = CodeBack;
            previewBox.ForeColor = CodeFore;
            workLayout.Controls.Add(Wrap("文件/报告预览", previewBox), 0, 3);

            jobBox.Dock = DockStyle.Fill;
            jobBox.Font = new Font("Cascadia Code", 9F);
            jobBox.ReadOnly = true;
            jobBox.BorderStyle = BorderStyle.None;
            jobBox.BackColor = Color.FromArgb(248, 250, 244);
            jobBox.ForeColor = Ink;
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
            chatBox.BorderStyle = BorderStyle.None;
            chatBox.BackColor = Color.FromArgb(247, 250, 244);
            chatBox.ForeColor = Ink;
            chatBox.Font = new Font("Microsoft YaHei UI", 9.4F);
            chatBox.Text = "这里不会偷偷调用云端AI；它会根据项目结构和最近日志生成一份Codex任务草稿，方便回到主对话继续让Codex写PLC程序、改LAD、跑验证。\n";
            aiLayout.Controls.Add(chatBox, 0, 0);

            requestBox.Dock = DockStyle.Fill;
            requestBox.Multiline = true;
            requestBox.ScrollBars = ScrollBars.Vertical;
            StyleInput(requestBox);
            requestBox.Text = "例如：把FC5自动流程增加取料超时报警，用LAD写入并在克隆工程中编译验证。";
            aiLayout.Controls.Add(requestBox, 0, 1);

            Button promptButton = NewButton("生成 Codex 任务草稿", Teal);
            promptButton.Dock = DockStyle.Fill;
            promptButton.Click += delegate { CreateAiPrompt(); };
            aiLayout.Controls.Add(promptButton, 0, 2);

            Panel bottom = new Panel();
            bottom.Dock = DockStyle.Bottom;
            bottom.Height = 28;
            bottom.BackColor = Color.FromArgb(224, 231, 222);
            Controls.Add(bottom);

            Label safety = new Label();
            safety.Text = "安全策略：读写分离 · 先克隆验证 · 不并发打开TIA工程 · 主工程写入前人工确认";
            safety.Dock = DockStyle.Fill;
            safety.TextAlign = ContentAlignment.MiddleLeft;
            safety.Padding = new Padding(16, 0, 0, 0);
            safety.ForeColor = MutedInk;
            bottom.Controls.Add(safety);

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
            ThemedGroupBox box = new ThemedGroupBox();
            box.Text = title;
            box.Padding = new Padding(12, 28, 12, 12);
            box.BackColor = Card;
            box.ForeColor = Ink;
            return box;
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
            Button button = new AccentButton();
            button.Text = text;
            button.Height = 38;
            button.FlatStyle = FlatStyle.Flat;
            button.FlatAppearance.BorderSize = 0;
            button.BackColor = color;
            button.ForeColor = Color.White;
            button.Margin = new Padding(5);
            button.Cursor = Cursors.Hand;
            button.Font = new Font("Microsoft YaHei UI", 9F, FontStyle.Bold);
            return button;
        }

        private static void StyleInput(TextBox box)
        {
            box.BorderStyle = BorderStyle.FixedSingle;
            box.BackColor = Color.FromArgb(255, 254, 248);
            box.ForeColor = Ink;
            box.Font = new Font("Microsoft YaHei UI", 9F);
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

    internal sealed class BannerPanel : Panel
    {
        public BannerPanel()
        {
            DoubleBuffered = true;
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            Rectangle rect = ClientRectangle;
            if (rect.Width <= 0 || rect.Height <= 0)
            {
                base.OnPaint(e);
                return;
            }

            using (LinearGradientBrush brush = new LinearGradientBrush(rect, Color.FromArgb(13, 42, 45), Color.FromArgb(22, 105, 101), LinearGradientMode.Horizontal))
            {
                e.Graphics.FillRectangle(brush, rect);
            }

            e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
            using (SolidBrush glow = new SolidBrush(Color.FromArgb(42, 242, 190, 93)))
            {
                e.Graphics.FillEllipse(glow, rect.Width - 290, -96, 340, 210);
            }
            using (SolidBrush wash = new SolidBrush(Color.FromArgb(34, 224, 111, 45)))
            {
                e.Graphics.FillEllipse(wash, rect.Width - 470, 32, 320, 140);
            }
            using (Pen line = new Pen(Color.FromArgb(70, 255, 255, 255), 1F))
            {
                e.Graphics.DrawLine(line, 0, rect.Height - 1, rect.Width, rect.Height - 1);
            }
        }
    }

    internal sealed class ThemedGroupBox : GroupBox
    {
        public ThemedGroupBox()
        {
            DoubleBuffered = true;
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
            Rectangle rect = new Rectangle(1, 10, Width - 3, Height - 12);
            using (GraphicsPath path = RoundedRect(rect, 16))
            using (SolidBrush fill = new SolidBrush(BackColor))
            using (Pen border = new Pen(Color.FromArgb(190, 205, 198), 1F))
            {
                e.Graphics.FillPath(fill, path);
                e.Graphics.DrawPath(border, path);
            }

            Rectangle titleRect = new Rectangle(16, 0, Math.Min(Width - 32, 260), 24);
            using (SolidBrush titleBack = new SolidBrush(Color.FromArgb(8, 128, 124)))
            using (GraphicsPath titlePath = RoundedRect(titleRect, 12))
            {
                e.Graphics.FillPath(titleBack, titlePath);
            }
            using (SolidBrush textBrush = new SolidBrush(Color.White))
            {
                e.Graphics.DrawString(Text, new Font(Font.FontFamily, 9F, FontStyle.Bold), textBrush, new PointF(28, 4));
            }
        }

        private static GraphicsPath RoundedRect(Rectangle rect, int radius)
        {
            GraphicsPath path = new GraphicsPath();
            int d = radius * 2;
            path.AddArc(rect.Left, rect.Top, d, d, 180, 90);
            path.AddArc(rect.Right - d, rect.Top, d, d, 270, 90);
            path.AddArc(rect.Right - d, rect.Bottom - d, d, d, 0, 90);
            path.AddArc(rect.Left, rect.Bottom - d, d, d, 90, 90);
            path.CloseFigure();
            return path;
        }
    }

    internal sealed class AccentButton : Button
    {
        private bool hovering;
        private bool pressing;

        public AccentButton()
        {
            DoubleBuffered = true;
            SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer, true);
        }

        protected override void OnMouseEnter(EventArgs e)
        {
            hovering = true;
            Invalidate();
            base.OnMouseEnter(e);
        }

        protected override void OnMouseLeave(EventArgs e)
        {
            hovering = false;
            pressing = false;
            Invalidate();
            base.OnMouseLeave(e);
        }

        protected override void OnMouseDown(MouseEventArgs mevent)
        {
            pressing = true;
            Invalidate();
            base.OnMouseDown(mevent);
        }

        protected override void OnMouseUp(MouseEventArgs mevent)
        {
            pressing = false;
            Invalidate();
            base.OnMouseUp(mevent);
        }

        protected override void OnPaint(PaintEventArgs pevent)
        {
            pevent.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
            Rectangle rect = new Rectangle(0, 0, Width - 1, Height - 1);
            Color baseColor = BackColor;
            Color top = Blend(baseColor, Color.White, hovering ? 0.18F : 0.08F);
            Color bottom = Blend(baseColor, Color.Black, pressing ? 0.18F : 0.05F);

            using (GraphicsPath path = RoundedRect(rect, 12))
            using (LinearGradientBrush fill = new LinearGradientBrush(rect, top, bottom, LinearGradientMode.Vertical))
            using (Pen border = new Pen(Color.FromArgb(90, Color.White), 1F))
            {
                pevent.Graphics.FillPath(fill, path);
                pevent.Graphics.DrawPath(border, path);
            }

            TextRenderer.DrawText(pevent.Graphics, Text, Font, rect, ForeColor, TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis);
        }

        private static Color Blend(Color a, Color b, float amount)
        {
            amount = Math.Max(0F, Math.Min(1F, amount));
            int r = (int)(a.R + ((b.R - a.R) * amount));
            int g = (int)(a.G + ((b.G - a.G) * amount));
            int bl = (int)(a.B + ((b.B - a.B) * amount));
            return Color.FromArgb(a.A, r, g, bl);
        }

        private static GraphicsPath RoundedRect(Rectangle rect, int radius)
        {
            GraphicsPath path = new GraphicsPath();
            int d = radius * 2;
            path.AddArc(rect.Left, rect.Top, d, d, 180, 90);
            path.AddArc(rect.Right - d, rect.Top, d, d, 270, 90);
            path.AddArc(rect.Right - d, rect.Bottom - d, d, d, 0, 90);
            path.AddArc(rect.Left, rect.Bottom - d, d, d, 90, 90);
            path.CloseFigure();
            return path;
        }
    }
}
