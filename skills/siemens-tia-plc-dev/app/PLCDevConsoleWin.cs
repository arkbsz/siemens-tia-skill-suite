using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
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
            Application.ThreadException += delegate (object sender, ThreadExceptionEventArgs eventArgs)
            {
                WriteCrashLog(eventArgs.Exception);
                MessageBox.Show(eventArgs.Exception.Message, "PLCDevConsole 运行错误", MessageBoxButtons.OK, MessageBoxIcon.Error);
            };
            AppDomain.CurrentDomain.UnhandledException += delegate (object sender, UnhandledExceptionEventArgs eventArgs)
            {
                WriteCrashLog(eventArgs.ExceptionObject as Exception);
            };
            Application.Run(new MainForm(projectPath, invokeScript));
        }

        private static void WriteCrashLog(Exception exception)
        {
            try
            {
                string root = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".codex", "logs");
                Directory.CreateDirectory(root);
                string path = Path.Combine(root, "PLCDevConsole.crash.log");
                File.AppendAllText(path, DateTime.Now.ToString("s") + Environment.NewLine + Convert.ToString(exception) + Environment.NewLine + Environment.NewLine, Encoding.UTF8);
            }
            catch
            {
            }
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
        private readonly ComboBox modelBox = new ComboBox();
        private readonly ComboBox workflowSelectBox = new ComboBox();
        private readonly ComboBox fontBox = new ComboBox();
        private readonly ComboBox fontSizeBox = new ComboBox();
        private readonly TabControl mainTabs = new TabControl();
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
            else
            {
                BeginInvoke((Action)delegate { AutoLoadCurrentTiaProject(false); });
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
            top.Height = 104;
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
            projectPathBox.Location = new Point(370, 16);
            projectPathBox.Width = 560;
            StyleInput(projectPathBox);
            top.Controls.Add(projectPathBox);

            Button autoButton = NewButton("读取当前TIA", Teal);
            autoButton.Anchor = AnchorStyles.Top | AnchorStyles.Right;
            autoButton.Location = new Point(944, 14);
            autoButton.Width = 120;
            autoButton.Click += delegate { AutoLoadCurrentTiaProject(); };
            top.Controls.Add(autoButton);

            Button browseButton = NewButton("浏览打开", Ink);
            browseButton.Anchor = AnchorStyles.Top | AnchorStyles.Right;
            browseButton.Location = new Point(1072, 14);
            browseButton.Width = 106;
            browseButton.Click += delegate { BrowseProject(); };
            top.Controls.Add(browseButton);

            Button loadButton = NewButton("加载项目", Teal);
            loadButton.Anchor = AnchorStyles.Top | AnchorStyles.Right;
            loadButton.Location = new Point(1186, 14);
            loadButton.Width = 100;
            loadButton.Click += delegate { LoadProject(projectPathBox.Text); };
            top.Controls.Add(loadButton);

            Button openProjectButton = NewButton("TIA打开", Orange);
            openProjectButton.Location = new Point(370, 54);
            openProjectButton.Width = 100;
            openProjectButton.Height = 32;
            openProjectButton.Click += delegate { OpenProjectWithDefaultApp(); };
            top.Controls.Add(openProjectButton);

            Button openFolderButton = NewButton("打开文件夹", Ink);
            openFolderButton.Location = new Point(478, 54);
            openFolderButton.Width = 112;
            openFolderButton.Height = 32;
            openFolderButton.Click += delegate { OpenProjectFolder(); };
            top.Controls.Add(openFolderButton);

            projectBadge.Anchor = AnchorStyles.Top | AnchorStyles.Right;
            projectBadge.Text = "V16-V21";
            projectBadge.ForeColor = Color.FromArgb(28, 45, 42);
            projectBadge.BackColor = Gold;
            projectBadge.Font = new Font(Font.FontFamily, 9F, FontStyle.Bold);
            projectBadge.TextAlign = ContentAlignment.MiddleCenter;
            projectBadge.Location = new Point(1298, 17);
            projectBadge.Size = new Size(82, 28);
            top.Controls.Add(projectBadge);

            statusLabel.Anchor = AnchorStyles.Top | AnchorStyles.Right;
            statusLabel.ForeColor = Color.FromArgb(244, 202, 145);
            statusLabel.AutoSize = true;
            statusLabel.Location = new Point(944, 58);
            statusLabel.BackColor = Color.Transparent;
            top.Controls.Add(statusLabel);

            SplitContainer outer = new SplitContainer();
            outer.Dock = DockStyle.Fill;
            outer.SplitterWidth = 6;
            outer.Panel1MinSize = 1;
            outer.Panel2MinSize = 1;
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

            SplitContainer center = new SplitContainer();
            center.Dock = DockStyle.Fill;
            center.Orientation = Orientation.Horizontal;
            center.SplitterWidth = 7;
            center.Panel1MinSize = 1;
            center.Panel2MinSize = 1;
            center.BackColor = Canvas;
            outer.Panel2.Controls.Add(center);

            GroupBox mainBox = NewGroup("主界面");
            mainBox.Dock = DockStyle.Fill;
            center.Panel1.Controls.Add(mainBox);

            TableLayoutPanel mainLayout = new TableLayoutPanel();
            mainLayout.Dock = DockStyle.Fill;
            mainLayout.RowCount = 2;
            mainLayout.ColumnCount = 1;
            mainLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 106));
            mainLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
            mainBox.Controls.Add(mainLayout);

            FlowLayoutPanel actions = new FlowLayoutPanel();
            actions.Dock = DockStyle.Fill;
            actions.Padding = new Padding(8, 8, 8, 4);
            actions.BackColor = Card;
            actions.Controls.Add(CommandButton("Doctor 检查", "doctor", Ink));
            actions.Controls.Add(CommandButton("快速读取", "read-cycle-skip", Teal));
            actions.Controls.Add(CommandButton("完整导出", "read-cycle-full", Orange));
            actions.Controls.Add(CommandButton("列程序块", "list-blocks", Ink));
            mainLayout.Controls.Add(actions, 0, 0);

            TableLayoutPanel writePanel = new TableLayoutPanel();
            writePanel.Width = 590;
            writePanel.Height = 86;
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
            actions.Controls.Add(writePanel);

            runList.Dock = DockStyle.Fill;
            runList.BorderStyle = BorderStyle.None;
            runList.BackColor = CardSoft;
            runList.ForeColor = Ink;
            runList.Font = new Font("Cascadia Mono", 9F);
            runList.ItemHeight = 22;

            previewBox.Dock = DockStyle.Fill;
            previewBox.Font = new Font("Cascadia Code", 9F);
            previewBox.ReadOnly = true;
            previewBox.BorderStyle = BorderStyle.None;
            previewBox.BackColor = CodeBack;
            previewBox.ForeColor = CodeFore;

            jobBox.Dock = DockStyle.Fill;
            jobBox.Font = new Font("Cascadia Code", 9F);
            jobBox.ReadOnly = true;
            jobBox.BorderStyle = BorderStyle.None;
            jobBox.BackColor = Color.FromArgb(248, 250, 244);
            jobBox.ForeColor = Ink;

            chatBox.Dock = DockStyle.Fill;
            chatBox.ReadOnly = true;
            chatBox.BorderStyle = BorderStyle.None;
            chatBox.BackColor = Color.FromArgb(247, 250, 244);
            chatBox.ForeColor = Ink;
            chatBox.Font = new Font("Microsoft YaHei UI", 9.4F);
            chatBox.Text = "AI 对话主界面\n\n这里会记录你提交的任务草稿、模型和工作流选择。真正的程序生成、LAD修改和克隆验证仍由 Codex 主对话或 workflow 脚本执行。\n";

            mainTabs.Dock = DockStyle.Fill;
            mainTabs.Font = new Font("Microsoft YaHei UI", 9.6F, FontStyle.Bold);
            mainTabs.Appearance = TabAppearance.Normal;
            mainTabs.Controls.Add(NewTab("AI 对话", chatBox));
            mainTabs.Controls.Add(NewTab("日志输出", jobBox));
            mainTabs.Controls.Add(NewTab("文件预览", previewBox));
            mainTabs.Controls.Add(NewTab("Runs", runList));
            mainLayout.Controls.Add(mainTabs, 0, 1);

            GroupBox aiInputBox = NewGroup("AI交互与工作流");
            aiInputBox.Dock = DockStyle.Fill;
            center.Panel2.Controls.Add(aiInputBox);

            TableLayoutPanel aiLayout = new TableLayoutPanel();
            aiLayout.Dock = DockStyle.Fill;
            aiLayout.RowCount = 2;
            aiLayout.ColumnCount = 1;
            aiLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 42));
            aiLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
            aiInputBox.Controls.Add(aiLayout);

            FlowLayoutPanel aiOptions = new FlowLayoutPanel();
            aiOptions.Dock = DockStyle.Fill;
            aiOptions.Padding = new Padding(8, 3, 8, 2);
            aiOptions.BackColor = Card;
            aiOptions.Controls.Add(NewSmallLabel("模型"));
            ConfigureCombo(modelBox, new string[] { "gpt-5-codex", "gpt-5", "gpt-5-mini", "本地/手动" }, "gpt-5-codex", 128);
            aiOptions.Controls.Add(modelBox);
            aiOptions.Controls.Add(NewSmallLabel("工作流"));
            ConfigureCombo(workflowSelectBox, new string[] { "读取项目并总结", "LAD编写与验证", "DB+程序块协同", "WinCC画面生成", "故障诊断", "工业化重构" }, "LAD编写与验证", 150);
            aiOptions.Controls.Add(workflowSelectBox);
            aiOptions.Controls.Add(NewSmallLabel("字体"));
            PopulateFontOptions();
            fontBox.Width = 170;
            aiOptions.Controls.Add(fontBox);
            aiOptions.Controls.Add(NewSmallLabel("字号"));
            ConfigureCombo(fontSizeBox, new string[] { "9", "10", "11", "12", "14", "16", "18" }, "10", 62);
            aiOptions.Controls.Add(fontSizeBox);
            Button applyFont = NewButton("应用字体", Ink);
            applyFont.Width = 92;
            applyFont.Click += delegate { ApplySelectedFont(); };
            aiOptions.Controls.Add(applyFont);
            aiLayout.Controls.Add(aiOptions, 0, 0);

            TableLayoutPanel inputLayout = new TableLayoutPanel();
            inputLayout.Dock = DockStyle.Fill;
            inputLayout.ColumnCount = 2;
            inputLayout.RowCount = 1;
            inputLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            inputLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 168));
            aiLayout.Controls.Add(inputLayout, 0, 1);

            requestBox.Dock = DockStyle.Fill;
            requestBox.Multiline = true;
            requestBox.ScrollBars = ScrollBars.Vertical;
            StyleInput(requestBox);
            requestBox.Text = "例如：把FC5自动流程增加取料超时报警，用LAD写入并在克隆工程中编译验证。";
            inputLayout.Controls.Add(requestBox, 0, 0);

            Button promptButton = NewButton("生成 Codex 任务草稿", Teal);
            promptButton.Dock = DockStyle.Fill;
            promptButton.Click += delegate { CreateAiPrompt(); };
            inputLayout.Controls.Add(promptButton, 1, 0);

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

            Shown += delegate
            {
                SafeConfigureSplitter(outer, 240, 560, 360);
                SafeConfigureSplitter(center, 300, 150, Math.Max(360, center.Height - 230));
            };
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

            fontSizeBox.SelectedIndexChanged += delegate { ApplySelectedFont(); };
            fontBox.SelectedIndexChanged += delegate { ApplySelectedFont(); };
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

        private static TabPage NewTab(string title, Control inner)
        {
            TabPage page = new TabPage(title);
            page.BackColor = Card;
            page.Padding = new Padding(8);
            inner.Dock = DockStyle.Fill;
            page.Controls.Add(inner);
            return page;
        }

        private static Label NewSmallLabel(string text)
        {
            return new Label
            {
                Text = text,
                AutoSize = false,
                Width = 40,
                Height = 28,
                TextAlign = ContentAlignment.MiddleRight,
                ForeColor = MutedInk,
                Margin = new Padding(8, 2, 2, 2)
            };
        }

        private static void ConfigureCombo(ComboBox combo, string[] values, string selected, int width)
        {
            combo.DropDownStyle = ComboBoxStyle.DropDownList;
            combo.Width = width;
            combo.Height = 28;
            combo.FlatStyle = FlatStyle.Flat;
            combo.BackColor = Color.FromArgb(255, 254, 248);
            combo.ForeColor = Ink;
            combo.Items.Clear();
            combo.Items.AddRange(values);
            combo.SelectedItem = selected;
            if (combo.SelectedIndex < 0 && combo.Items.Count > 0)
            {
                combo.SelectedIndex = 0;
            }
        }

        private void PopulateFontOptions()
        {
            fontBox.DropDownStyle = ComboBoxStyle.DropDownList;
            fontBox.FlatStyle = FlatStyle.Flat;
            fontBox.BackColor = Color.FromArgb(255, 254, 248);
            fontBox.ForeColor = Ink;
            fontBox.Items.Clear();

            InstalledFontCollection installed = new InstalledFontCollection();
            foreach (FontFamily family in installed.Families)
            {
                if (family.IsStyleAvailable(FontStyle.Regular))
                {
                    fontBox.Items.Add(family.Name);
                }
            }

            string preferred = FontFamilyExists("Microsoft YaHei UI") ? "Microsoft YaHei UI" : Font.FontFamily.Name;
            fontBox.SelectedItem = preferred;
            if (fontBox.SelectedIndex < 0 && fontBox.Items.Count > 0)
            {
                fontBox.SelectedIndex = 0;
            }
        }

        private static bool FontFamilyExists(string name)
        {
            InstalledFontCollection installed = new InstalledFontCollection();
            foreach (FontFamily family in installed.Families)
            {
                if (string.Equals(family.Name, name, StringComparison.OrdinalIgnoreCase))
                {
                    return true;
                }
            }
            return false;
        }

        private void ApplySelectedFont()
        {
            try
            {
                string family = Convert.ToString(fontBox.SelectedItem);
                float size = 10F;
                float.TryParse(Convert.ToString(fontSizeBox.SelectedItem), out size);
                Font uiFont = new Font(family, size, FontStyle.Regular);
                Font codeFont = new Font(FontFamilyExists("Cascadia Code") ? "Cascadia Code" : family, Math.Max(8F, size - 0.5F), FontStyle.Regular);

                ApplyFontRecursive(this, uiFont);
                previewBox.Font = codeFont;
                jobBox.Font = codeFont;
                runList.Font = new Font(FontFamilyExists("Cascadia Mono") ? "Cascadia Mono" : family, Math.Max(8F, size - 0.5F), FontStyle.Regular);
                projectTree.ItemHeight = Math.Max(22, (int)(size * 2.4F));
                statusLabel.Text = "字体已应用：" + family + " " + size.ToString("0");
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "字体应用失败", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }

        private static void ApplyFontRecursive(Control control, Font font)
        {
            if (!(control is RichTextBox))
            {
                control.Font = font;
            }
            foreach (Control child in control.Controls)
            {
                ApplyFontRecursive(child, font);
            }
        }

        private Button CommandButton(string text, string command, Color color)
        {
            Button button = NewButton(text, color);
            button.Width = 132;
            button.Click += delegate { StartCommand(command); };
            return button;
        }

        private static void SafeSetSplitterDistance(SplitContainer splitter, int requestedDistance)
        {
            try
            {
                if (splitter.Width <= 0 || splitter.Height <= 0)
                {
                    return;
                }

                int span = splitter.Orientation == Orientation.Vertical ? splitter.Width : splitter.Height;
                int max = span - splitter.Panel2MinSize - splitter.SplitterWidth;
                int min = splitter.Panel1MinSize;
                if (max <= min)
                {
                    return;
                }

                splitter.SplitterDistance = Math.Max(min, Math.Min(max, requestedDistance));
            }
            catch
            {
            }
        }

        private static void SafeConfigureSplitter(SplitContainer splitter, int panel1Min, int panel2Min, int requestedDistance)
        {
            try
            {
                int span = splitter.Orientation == Orientation.Vertical ? splitter.Width : splitter.Height;
                if (span <= panel1Min + panel2Min + splitter.SplitterWidth)
                {
                    return;
                }

                splitter.Panel1MinSize = panel1Min;
                splitter.Panel2MinSize = panel2Min;
                SafeSetSplitterDistance(splitter, requestedDistance);
            }
            catch
            {
            }
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

        private void BrowseProject()
        {
            OpenFileDialog dialog = new OpenFileDialog();
            dialog.Title = "选择 TIA Portal 项目文件";
            dialog.Filter = "TIA Portal Projects (*.ap16;*.ap17;*.ap18;*.ap19;*.ap20;*.ap21)|*.ap16;*.ap17;*.ap18;*.ap19;*.ap20;*.ap21|All files (*.*)|*.*";
            dialog.InitialDirectory = Directory.Exists(projectPathBox.Text) ? projectPathBox.Text : Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments);
            if (dialog.ShowDialog(this) == DialogResult.OK)
            {
                LoadProject(dialog.FileName);
                return;
            }

            FolderBrowserDialog folder = new FolderBrowserDialog();
            folder.Description = "也可以选择 TIA 项目所在文件夹";
            if (Directory.Exists(projectPathBox.Text))
            {
                folder.SelectedPath = projectPathBox.Text;
            }
            if (folder.ShowDialog(this) == DialogResult.OK)
            {
                LoadProject(folder.SelectedPath);
            }
        }

        private void AutoLoadCurrentTiaProject()
        {
            AutoLoadCurrentTiaProject(true);
        }

        private void AutoLoadCurrentTiaProject(bool showBrowseWhenMissing)
        {
            try
            {
                string detected = DetectCurrentTiaProjectPath();
                if (string.IsNullOrWhiteSpace(detected))
                {
                    statusLabel.Text = "未识别到当前TIA项目";
                    if (showBrowseWhenMissing)
                    {
                        MessageBox.Show("没有自动识别到当前 TIA 项目路径。可以点击“浏览打开”选择 .ap16-.ap21 文件。", "需要选择项目", MessageBoxButtons.OK, MessageBoxIcon.Information);
                        BrowseProject();
                    }
                    return;
                }

                LoadProject(detected);
                statusLabel.Text = "已自动识别项目";
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "自动读取失败", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }

        private void OpenProjectWithDefaultApp()
        {
            try
            {
                string root = ResolveProjectRoot(projectPathBox.Text);
                string projectFile = FindFirstProjectFile(root);
                if (string.IsNullOrWhiteSpace(projectFile))
                {
                    throw new FileNotFoundException("当前目录下没有找到 .ap16-.ap21 项目文件。", root);
                }

                ProcessStartInfo start = new ProcessStartInfo();
                start.FileName = projectFile;
                start.UseShellExecute = true;
                Process.Start(start);
                statusLabel.Text = "已交给TIA/默认程序打开";
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "打开TIA项目失败", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }

        private void OpenProjectFolder()
        {
            try
            {
                string root = ResolveProjectRoot(projectPathBox.Text);
                Process.Start("explorer.exe", QuoteForExplorer(root));
                statusLabel.Text = "已打开项目文件夹";
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "打开文件夹失败", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }

        private string DetectCurrentTiaProjectPath()
        {
            List<string> candidates = new List<string>();
            candidates.AddRange(ProjectPathsFromTiaCommandLines());

            if (!string.IsNullOrWhiteSpace(projectPathBox.Text))
            {
                AddProjectCandidates(candidates, projectPathBox.Text);
            }

            AddProjectCandidates(candidates, Directory.GetCurrentDirectory());
            AddProjectCandidates(candidates, Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "Documents"));
            AddProjectCandidates(candidates, Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "Downloads"));
            AddLikelyProjectRoots(candidates);

            string newest = "";
            DateTime newestTime = DateTime.MinValue;
            foreach (string path in candidates)
            {
                if (string.IsNullOrWhiteSpace(path))
                {
                    continue;
                }
                string root = ResolveProjectRoot(path);
                string projectFile = FindFirstProjectFile(root);
                if (string.IsNullOrWhiteSpace(projectFile))
                {
                    continue;
                }
                DateTime time = File.GetLastWriteTime(projectFile);
                if (time > newestTime)
                {
                    newestTime = time;
                    newest = projectFile;
                }
            }
            return newest;
        }

        private static void AddLikelyProjectRoots(List<string> candidates)
        {
            try
            {
                foreach (DriveInfo drive in DriveInfo.GetDrives())
                {
                    if (!drive.IsReady || drive.DriveType != DriveType.Fixed)
                    {
                        continue;
                    }

                    AddProjectCandidates(candidates, Path.Combine(drive.RootDirectory.FullName, "plc"));
                    AddProjectCandidates(candidates, Path.Combine(drive.RootDirectory.FullName, "PLC"));
                    AddProjectCandidates(candidates, Path.Combine(drive.RootDirectory.FullName, "TIA"));
                }
            }
            catch
            {
            }
        }

        private static List<string> ProjectPathsFromTiaCommandLines()
        {
            List<string> rows = new List<string>();
            try
            {
                ProcessStartInfo start = new ProcessStartInfo();
                start.FileName = "powershell.exe";
                start.Arguments = "-NoProfile -Command \"Get-CimInstance Win32_Process | Where-Object { $_.Name -like 'Siemens.Automation.Portal*' } | Select-Object -ExpandProperty CommandLine\"";
                start.UseShellExecute = false;
                start.CreateNoWindow = true;
                start.RedirectStandardOutput = true;
                start.RedirectStandardError = true;
                using (Process process = Process.Start(start))
                {
                    string text = process.StandardOutput.ReadToEnd();
                    process.WaitForExit(5000);
                    foreach (string line in text.Split(new string[] { "\r\n", "\n" }, StringSplitOptions.RemoveEmptyEntries))
                    {
                        foreach (string candidate in ExtractProjectPaths(line))
                        {
                            rows.Add(candidate);
                        }
                    }
                }
            }
            catch
            {
            }
            return rows;
        }

        private static IEnumerable<string> ExtractProjectPaths(string text)
        {
            if (string.IsNullOrWhiteSpace(text))
            {
                yield break;
            }

            Regex pathPattern = new Regex("\"(?<path>[^\"]+\\.ap(?:16|17|18|19|20|21))\"|(?<path>[^\\s\"]+\\.ap(?:16|17|18|19|20|21))", RegexOptions.IgnoreCase);
            foreach (Match match in pathPattern.Matches(text))
            {
                string candidate = match.Groups["path"].Value.Trim();
                if (!string.IsNullOrWhiteSpace(candidate))
                {
                    yield return candidate;
                }
            }
        }

        private static void AddProjectCandidates(List<string> candidates, string path)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(path) || !Directory.Exists(path) && !File.Exists(path))
                {
                    return;
                }
                if (File.Exists(path))
                {
                    candidates.Add(path);
                    return;
                }
                string projectFile = FindFirstProjectFile(path);
                if (string.IsNullOrWhiteSpace(projectFile))
                {
                    projectFile = FindFirstProjectFileDeep(path, 4);
                }
                if (!string.IsNullOrWhiteSpace(projectFile))
                {
                    candidates.Add(projectFile);
                }
            }
            catch
            {
            }
        }

        private static string FindFirstProjectFile(string root)
        {
            if (File.Exists(root) && IsTiaProjectFile(root))
            {
                return root;
            }
            if (!Directory.Exists(root))
            {
                return "";
            }

            string newest = "";
            DateTime newestTime = DateTime.MinValue;
            foreach (string file in Directory.GetFiles(root, "*.ap*", SearchOption.TopDirectoryOnly))
            {
                if (!IsTiaProjectFile(file))
                {
                    continue;
                }
                DateTime time = File.GetLastWriteTime(file);
                if (time > newestTime)
                {
                    newest = file;
                    newestTime = time;
                }
            }
            return newest;
        }

        private static string FindFirstProjectFileDeep(string root, int maxDepth)
        {
            if (!Directory.Exists(root) || maxDepth < 0)
            {
                return "";
            }

            string direct = FindFirstProjectFile(root);
            if (!string.IsNullOrWhiteSpace(direct))
            {
                return direct;
            }

            string newest = "";
            DateTime newestTime = DateTime.MinValue;
            foreach (string dir in SafeGetDirectories(root))
            {
                string name = Path.GetFileName(dir);
                if (name == ".git" || name == "_backup" || name == "node_modules" || name == "__pycache__")
                {
                    continue;
                }
                string candidate = FindFirstProjectFileDeep(dir, maxDepth - 1);
                if (string.IsNullOrWhiteSpace(candidate))
                {
                    continue;
                }
                DateTime time = File.GetLastWriteTime(candidate);
                if (time > newestTime)
                {
                    newestTime = time;
                    newest = candidate;
                }
            }
            return newest;
        }

        private static bool IsTiaProjectFile(string path)
        {
            string ext = Path.GetExtension(path).ToLowerInvariant();
            return ext == ".ap16" || ext == ".ap17" || ext == ".ap18" || ext == ".ap19" || ext == ".ap20" || ext == ".ap21";
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
            if (mainTabs.TabPages.Count >= 4)
            {
                mainTabs.SelectedIndex = 3;
            }
        }

        private void ShowFile(string path)
        {
            try
            {
                previewBox.Text = ReadText(path);
                if (mainTabs.TabPages.Count >= 3)
                {
                    mainTabs.SelectedIndex = 2;
                }
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
                if (mainTabs.TabPages.Count >= 2)
                {
                    mainTabs.SelectedIndex = 1;
                }
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

        private static string QuoteForExplorer(string value)
        {
            if (value == null)
            {
                return "\"\"";
            }
            return "\"" + value.Replace("\"", "\"\"") + "\"";
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
                content.AppendLine("Model: `" + Convert.ToString(modelBox.SelectedItem) + "`");
                content.AppendLine("Workflow: `" + Convert.ToString(workflowSelectBox.SelectedItem) + "`");
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
                chatBox.AppendText(Environment.NewLine + "用户任务：" + requestBox.Text.Trim() + Environment.NewLine);
                chatBox.AppendText("模型：" + Convert.ToString(modelBox.SelectedItem) + "    工作流：" + Convert.ToString(workflowSelectBox.SelectedItem) + Environment.NewLine);
                chatBox.AppendText("已生成任务草稿：" + path + Environment.NewLine);
                previewBox.Text = ReadText(path);
                if (mainTabs.TabPages.Count > 0)
                {
                    mainTabs.SelectedIndex = 0;
                }
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
