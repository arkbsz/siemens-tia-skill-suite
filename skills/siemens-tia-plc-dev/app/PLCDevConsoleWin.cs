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
        private readonly MenuStrip mainMenu = new MenuStrip();
        private readonly ComboBox modelBox = new ComboBox();
        private readonly ComboBox workflowSelectBox = new ComboBox();
        private readonly ComboBox apiProviderBox = new ComboBox();
        private readonly ComboBox imageWorkflowBox = new ComboBox();
        private readonly ComboBox imageModelBox = new ComboBox();
        private readonly ComboBox imageQualityBox = new ComboBox();
        private readonly ComboBox imageSizeBox = new ComboBox();
        private readonly ComboBox componentStrategyBox = new ComboBox();
        private readonly ComboBox fontBox = new ComboBox();
        private readonly ComboBox fontSizeBox = new ComboBox();
        private readonly TextBox apiBaseBox = new TextBox();
        private readonly TextBox apiKeyEnvBox = new TextBox();
        private readonly TextBox referenceImageBox = new TextBox();
        private readonly PictureBox referencePreviewBox = new PictureBox();
        private readonly TabControl mainTabs = new TabControl();
        private readonly System.Windows.Forms.Timer tailTimer = new System.Windows.Forms.Timer();
        private readonly string invokeScript;
        private SplitContainer outerSplitter;
        private SplitContainer centerSplitter;

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
        private bool applyingWorkflowDefaults;

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

            ConfigureSettingsControls();
            BuildMainMenu();
            Controls.Add(mainMenu);
            MainMenuStrip = mainMenu;

            Panel top = new BannerPanel();
            top.Dock = DockStyle.Top;
            top.Height = 104;
            top.Padding = new Padding(18, 14, 18, 14);
            top.BackColor = Rail;
            Controls.Add(top);
            mainMenu.BringToFront();

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
            outerSplitter = outer;
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
            centerSplitter = center;
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

            referencePreviewBox.Dock = DockStyle.Fill;
            referencePreviewBox.BackColor = Color.FromArgb(28, 47, 48);
            referencePreviewBox.BorderStyle = BorderStyle.None;
            referencePreviewBox.SizeMode = PictureBoxSizeMode.Zoom;

            mainTabs.Dock = DockStyle.Fill;
            mainTabs.Font = new Font("Microsoft YaHei UI", 9.6F, FontStyle.Bold);
            mainTabs.Appearance = TabAppearance.Normal;
            mainTabs.Controls.Add(NewTab("AI 对话", chatBox));
            mainTabs.Controls.Add(NewTab("日志输出", jobBox));
            mainTabs.Controls.Add(NewTab("文件预览", previewBox));
            mainTabs.Controls.Add(NewTab("Runs", runList));
            mainTabs.Controls.Add(NewTab("参考图", referencePreviewBox));
            mainLayout.Controls.Add(mainTabs, 0, 1);

            GroupBox aiInputBox = NewGroup("AI交互与工作流");
            aiInputBox.Dock = DockStyle.Fill;
            center.Panel2.Controls.Add(aiInputBox);

            TableLayoutPanel aiLayout = new TableLayoutPanel();
            aiLayout.Dock = DockStyle.Fill;
            aiLayout.RowCount = 1;
            aiLayout.ColumnCount = 1;
            aiLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
            aiInputBox.Controls.Add(aiLayout);

            TableLayoutPanel inputLayout = new TableLayoutPanel();
            inputLayout.Dock = DockStyle.Fill;
            inputLayout.ColumnCount = 2;
            inputLayout.RowCount = 1;
            inputLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            inputLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 168));
            aiLayout.Controls.Add(inputLayout, 0, 0);

            requestBox.Dock = DockStyle.Fill;
            requestBox.Multiline = true;
            requestBox.ScrollBars = ScrollBars.Vertical;
            StyleInput(requestBox);
            requestBox.Text = "例如：参考上传的画面截图，生成一个 WinCC 总览+手动+报警界面方案，自动匹配电机/气缸/报警组件，并输出可导入的画面设计任务。";
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
                SafeConfigureSplitter(center, 300, 240, Math.Max(340, center.Height - 310));
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
            workflowSelectBox.SelectedIndexChanged += delegate { ApplyWorkflowDefaults(false); };
            requestBox.TextChanged += delegate { ApplyWorkflowDefaults(true); };
            referenceImageBox.TextChanged += delegate
            {
                if (File.Exists(referenceImageBox.Text))
                {
                    LoadReferencePreview(referenceImageBox.Text);
                }
            };
        }

        private void ConfigureSettingsControls()
        {
            ConfigureCombo(modelBox, new string[] { "gpt-5-codex", "gpt-5", "gpt-5-mini", "本地/手动" }, "gpt-5-codex", 150);
            ConfigureCombo(workflowSelectBox, new string[] { "自动选择", "读取项目并总结", "LAD编写与验证", "DB+程序块协同", "WinCC画面生成", "WinCC参考图复刻", "故障诊断", "工业化重构" }, "自动选择", 168);
            ConfigureCombo(apiProviderBox, new string[] { "Codex内置", "OpenAI API", "Azure OpenAI", "本地/手动" }, "Codex内置", 142);
            ConfigureCombo(imageWorkflowBox, new string[] { "自动", "无图像", "文生图", "图生图/参考图" }, "自动", 142);
            ConfigureCombo(imageModelBox, new string[] { "内置imagegen", "gpt-image-2", "gpt-image-1.5", "自定义" }, "内置imagegen", 142);
            ConfigureCombo(imageQualityBox, new string[] { "auto", "high", "medium", "low" }, "auto", 96);
            ConfigureCombo(imageSizeBox, new string[] { "auto", "1536x1024", "1024x1024", "1920x1080", "3840x2160" }, "1536x1024", 122);
            ConfigureCombo(componentStrategyBox, new string[] { "自动匹配+自定义", "标准WinCC组件", "Faceplate优先", "自定义组件优先", "SiVArc规则生成" }, "自动匹配+自定义", 168);
            PopulateFontOptions();
            fontBox.Width = 178;
            ConfigureCombo(fontSizeBox, new string[] { "9", "10", "11", "12", "14", "16", "18" }, "10", 72);
            apiBaseBox.Width = 260;
            apiBaseBox.Text = "";
            StyleInput(apiBaseBox);
            apiKeyEnvBox.Width = 160;
            apiKeyEnvBox.Text = "OPENAI_API_KEY";
            StyleInput(apiKeyEnvBox);
            referenceImageBox.Width = 330;
            StyleInput(referenceImageBox);
        }

        private void BuildMainMenu()
        {
            mainMenu.Dock = DockStyle.Top;
            mainMenu.Height = 32;
            mainMenu.Padding = new Padding(4, 3, 4, 2);
            mainMenu.BackColor = Color.FromArgb(37, 39, 42);
            mainMenu.ForeColor = Color.FromArgb(238, 241, 232);
            mainMenu.Renderer = new DarkMenuRenderer();

            mainMenu.Items.Clear();
            mainMenu.Items.Add(BuildFileMenu());
            mainMenu.Items.Add(BuildSimpleMenu("编辑(&E)", new string[] { "撤销", "重做", "-", "复制", "粘贴", "查找" }));
            mainMenu.Items.Add(BuildViewMenu());
            mainMenu.Items.Add(BuildSimpleMenu("导航(&N)", new string[] { "定位到项目树", "定位到日志", "定位到文件预览", "定位到AI输入" }));
            mainMenu.Items.Add(BuildCodeMenu());
            mainMenu.Items.Add(BuildSimpleMenu("重构(&R)", new string[] { "生成命名规范任务", "生成DB/块协同任务", "生成工业化重构任务" }));
            mainMenu.Items.Add(BuildRunMenu());
            mainMenu.Items.Add(BuildToolsMenu());
            mainMenu.Items.Add(BuildSimpleMenu("Git(&G)", new string[] { "查看状态", "提交说明草稿", "同步仓库" }));
            mainMenu.Items.Add(BuildWindowMenu());
            mainMenu.Items.Add(BuildHelpMenu());
        }

        private ToolStripMenuItem BuildFileMenu()
        {
            ToolStripMenuItem file = NewMenu("文件(&F)");
            file.DropDownItems.Add(NewMenuItem("新建项目...", delegate { requestBox.Text = "新建一个 TIA Portal 项目，并生成 PLC/HMI 基础结构。"; CreateAiPrompt(); }));
            file.DropDownItems.Add(NewMenuItem("来自版本控制的项目...", delegate { requestBox.Text = "从 Git 仓库读取 Siemens TIA skill suite 或 PLC-as-code 项目，并初始化工作区。"; CreateAiPrompt(); }));
            file.DropDownItems.Add(NewMenuItem("新建任务草稿(&N)...", delegate { CreateAiPrompt(); }, Keys.Alt | Keys.Insert));
            file.DropDownItems.Add(NewMenuItem("打开(&O)...", delegate { BrowseProject(); }, Keys.Control | Keys.O));
            file.DropDownItems.Add(NewMenuItem("读取当前 TIA 项目", delegate { AutoLoadCurrentTiaProject(); }));
            file.DropDownItems.Add(NewMenuItem("用 TIA/默认程序打开", delegate { OpenProjectWithDefaultApp(); }));
            file.DropDownItems.Add(NewMenuItem("打开项目文件夹", delegate { OpenProjectFolder(); }));
            file.DropDownItems.Add(new ToolStripSeparator());
            file.DropDownItems.Add(NewMenuItem("设置(&T)...", delegate { ShowSettingsTabHint(); }, Keys.Control | Keys.Alt | Keys.S));
            file.DropDownItems.Add(NewMenuItem("上传 WinCC 参考图...", delegate { BrowseReferenceImage(); }));
            file.DropDownItems.Add(new ToolStripSeparator());
            file.DropDownItems.Add(NewMenuItem("全部保存(&S)", delegate { CreateAiPrompt(); }, Keys.Control | Keys.S));
            file.DropDownItems.Add(NewMenuItem("从磁盘全部重新加载", delegate { LoadProject(projectPathBox.Text); }, Keys.Control | Keys.Alt | Keys.Y));
            file.DropDownItems.Add(new ToolStripSeparator());
            file.DropDownItems.Add(NewMenuItem("退出(&X)", delegate { Close(); }));
            return file;
        }

        private ToolStripMenuItem BuildViewMenu()
        {
            ToolStripMenuItem view = NewMenu("视图(&V)");
            view.DropDownItems.Add(NewMenuItem("AI 对话", delegate { SelectMainTab(0); }));
            view.DropDownItems.Add(NewMenuItem("日志输出", delegate { SelectMainTab(1); }));
            view.DropDownItems.Add(NewMenuItem("文件预览", delegate { SelectMainTab(2); }));
            view.DropDownItems.Add(NewMenuItem("Runs 列表", delegate { SelectMainTab(3); }));
            view.DropDownItems.Add(NewMenuItem("参考图", delegate { SelectMainTab(4); }));
            view.DropDownItems.Add(new ToolStripSeparator());
            view.DropDownItems.Add(NewMenuItem("恢复默认布局", delegate { RestoreDefaultLayout(); }));
            return view;
        }

        private ToolStripMenuItem BuildCodeMenu()
        {
            ToolStripMenuItem code = NewMenu("代码(&C)");
            code.DropDownItems.Add(NewMenuItem("LAD 编写与验证", delegate { SelectCombo(workflowSelectBox, "LAD编写与验证"); ApplyWorkflowDefaults(false); }));
            code.DropDownItems.Add(NewMenuItem("DB + 程序块协同", delegate { SelectCombo(workflowSelectBox, "DB+程序块协同"); ApplyWorkflowDefaults(false); }));
            code.DropDownItems.Add(NewMenuItem("WinCC 画面生成", delegate { SelectCombo(workflowSelectBox, "WinCC画面生成"); ApplyWorkflowDefaults(false); }));
            code.DropDownItems.Add(NewMenuItem("WinCC 参考图复刻", delegate { SelectCombo(workflowSelectBox, "WinCC参考图复刻"); ApplyWorkflowDefaults(false); }));
            return code;
        }

        private ToolStripMenuItem BuildRunMenu()
        {
            ToolStripMenuItem run = NewMenu("运行(&U)");
            run.DropDownItems.Add(NewMenuItem("Doctor 检查", delegate { StartCommand("doctor"); }));
            run.DropDownItems.Add(NewMenuItem("快速读取", delegate { StartCommand("read-cycle-skip"); }));
            run.DropDownItems.Add(NewMenuItem("完整导出", delegate { StartCommand("read-cycle-full"); }));
            run.DropDownItems.Add(NewMenuItem("列程序块", delegate { StartCommand("list-blocks"); }));
            run.DropDownItems.Add(NewMenuItem("克隆验证 LAD", delegate { StartCommand("write-cycle"); }));
            return run;
        }

        private ToolStripMenuItem BuildToolsMenu()
        {
            ToolStripMenuItem tools = NewMenu("工具(&T)");
            tools.DropDownItems.Add(BuildSettingsPanelMenu("AI / API / 图像 / WinCC 设置"));
            tools.DropDownItems.Add(new ToolStripSeparator());
            tools.DropDownItems.Add(NewMenuItem("上传 WinCC 参考图...", delegate { BrowseReferenceImage(); }));
            tools.DropDownItems.Add(NewMenuItem("应用字体设置", delegate { ApplySelectedFont(); }));
            tools.DropDownItems.Add(NewMenuItem("按任务自动推荐模型", delegate { ApplyWorkflowDefaults(false); }));
            return tools;
        }

        private ToolStripMenuItem BuildWindowMenu()
        {
            ToolStripMenuItem window = NewMenu("窗口(&W)");
            window.DropDownItems.Add(NewMenuItem("左侧项目树加宽", delegate { ResizeProjectTree(420); }));
            window.DropDownItems.Add(NewMenuItem("左侧项目树收窄", delegate { ResizeProjectTree(280); }));
            window.DropDownItems.Add(NewMenuItem("底部 AI 区加高", delegate { ResizeAiPanel(320); }));
            window.DropDownItems.Add(NewMenuItem("底部 AI 区收起", delegate { ResizeAiPanel(180); }));
            window.DropDownItems.Add(new ToolStripSeparator());
            window.DropDownItems.Add(NewMenuItem("恢复默认布局", delegate { RestoreDefaultLayout(); }));
            return window;
        }

        private ToolStripMenuItem BuildHelpMenu()
        {
            ToolStripMenuItem help = NewMenu("帮助(&H)");
            help.DropDownItems.Add(NewMenuItem("关于", delegate
            {
                MessageBox.Show("Siemens TIA PLC Dev Console\n\n本地 WinForms 工程座舱：项目读取、LAD/DB/WinCC 任务草稿、Openness 工作流和参考图设计入口。", "关于", MessageBoxButtons.OK, MessageBoxIcon.Information);
            }));
            return help;
        }

        private ToolStripMenuItem BuildSimpleMenu(string title, string[] labels)
        {
            ToolStripMenuItem menu = NewMenu(title);
            foreach (string label in labels)
            {
                if (label == "-")
                {
                    menu.DropDownItems.Add(new ToolStripSeparator());
                }
                else
                {
                    menu.DropDownItems.Add(NewMenuItem(label, delegate { statusLabel.Text = "菜单功能待接入：" + label; }));
                }
            }
            return menu;
        }

        private ToolStripMenuItem BuildSettingsPanelMenu(string title)
        {
            ToolStripMenuItem item = NewMenu(title);
            Panel panel = new Panel();
            panel.Width = 620;
            panel.Height = 360;
            panel.AutoScroll = true;
            panel.BackColor = Color.FromArgb(35, 39, 43);

            TableLayoutPanel grid = new TableLayoutPanel();
            grid.Dock = DockStyle.Top;
            grid.AutoSize = true;
            grid.ColumnCount = 4;
            grid.RowCount = 9;
            grid.Padding = new Padding(12);
            grid.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 96));
            grid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50));
            grid.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 96));
            grid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50));
            panel.Controls.Add(grid);

            AddSettingRow(grid, 0, "代码模型", modelBox, "工作流", workflowSelectBox);
            AddSettingRow(grid, 1, "API 提供方", apiProviderBox, "API Base", apiBaseBox);
            AddSettingRow(grid, 2, "Key 环境变量", apiKeyEnvBox, "图像工作流", imageWorkflowBox);
            AddSettingRow(grid, 3, "图像模型", imageModelBox, "图像质量", imageQualityBox);
            AddSettingRow(grid, 4, "图像尺寸", imageSizeBox, "组件策略", componentStrategyBox);
            AddSettingRow(grid, 5, "界面字体", fontBox, "字号", fontSizeBox);
            AddSettingRow(grid, 6, "参考图", referenceImageBox, "", NewMenuButton("上传/预览", delegate { BrowseReferenceImage(); }));
            AddSettingRow(grid, 7, "应用", NewMenuButton("应用字体", delegate { ApplySelectedFont(); }), "推荐", NewMenuButton("自动推荐模型", delegate { ApplyWorkflowDefaults(false); }));
            AddSettingRow(grid, 8, "生成", NewMenuButton("生成任务草稿", delegate { CreateAiPrompt(); }), "预览", NewMenuButton("查看参考图", delegate { SelectMainTab(4); }));

            item.DropDownItems.Add(new ToolStripControlHost(panel)
            {
                Padding = new Padding(0),
                Margin = new Padding(0)
            });
            return item;
        }

        private static void AddSettingRow(TableLayoutPanel grid, int row, string leftLabel, Control leftControl, string rightLabel, Control rightControl)
        {
            grid.RowStyles.Add(new RowStyle(SizeType.Absolute, 38));
            AddSettingCell(grid, leftLabel, 0, row);
            grid.Controls.Add(leftControl, 1, row);
            leftControl.Dock = DockStyle.Fill;
            AddSettingCell(grid, rightLabel, 2, row);
            grid.Controls.Add(rightControl, 3, row);
            rightControl.Dock = DockStyle.Fill;
        }

        private static void AddSettingCell(TableLayoutPanel grid, string text, int col, int row)
        {
            Label label = new Label();
            label.Text = text;
            label.ForeColor = Color.FromArgb(216, 225, 221);
            label.TextAlign = ContentAlignment.MiddleRight;
            label.Dock = DockStyle.Fill;
            label.Margin = new Padding(3, 5, 8, 5);
            grid.Controls.Add(label, col, row);
        }

        private static Button NewMenuButton(string text, Action action)
        {
            Button button = new Button();
            button.Text = text;
            button.Height = 28;
            button.FlatStyle = FlatStyle.Flat;
            button.FlatAppearance.BorderColor = Color.FromArgb(84, 117, 113);
            button.BackColor = Color.FromArgb(51, 74, 73);
            button.ForeColor = Color.White;
            button.Click += delegate { action(); };
            return button;
        }

        private static ToolStripMenuItem NewMenu(string text)
        {
            ToolStripMenuItem item = new ToolStripMenuItem(text);
            item.ForeColor = Color.FromArgb(239, 244, 238);
            item.BackColor = Color.FromArgb(37, 39, 42);
            return item;
        }

        private static ToolStripMenuItem NewMenuItem(string text, Action action)
        {
            return NewMenuItem(text, action, Keys.None);
        }

        private static ToolStripMenuItem NewMenuItem(string text, Action action, Keys shortcut)
        {
            ToolStripMenuItem item = new ToolStripMenuItem(text);
            item.ForeColor = Color.FromArgb(238, 242, 235);
            item.BackColor = Color.FromArgb(38, 42, 46);
            item.ShortcutKeys = shortcut;
            item.Click += delegate { action(); };
            return item;
        }

        private void ShowSettingsTabHint()
        {
            statusLabel.Text = "设置位于 工具 > AI / API / 图像 / WinCC 设置";
        }

        private void SelectMainTab(int index)
        {
            if (index >= 0 && index < mainTabs.TabPages.Count)
            {
                mainTabs.SelectedIndex = index;
            }
        }

        private void RestoreDefaultLayout()
        {
            if (outerSplitter != null)
            {
                SafeConfigureSplitter(outerSplitter, 240, 560, 360);
            }
            if (centerSplitter != null)
            {
                SafeConfigureSplitter(centerSplitter, 300, 240, Math.Max(340, centerSplitter.Height - 310));
            }
            statusLabel.Text = "已恢复默认布局";
        }

        private void ResizeProjectTree(int width)
        {
            if (outerSplitter != null)
            {
                SafeSetSplitterDistance(outerSplitter, width);
                statusLabel.Text = "项目树宽度已调整";
            }
        }

        private void ResizeAiPanel(int height)
        {
            if (centerSplitter != null && centerSplitter.Orientation == Orientation.Horizontal)
            {
                SafeSetSplitterDistance(centerSplitter, Math.Max(300, centerSplitter.Height - height));
                statusLabel.Text = "底部AI区高度已调整";
            }
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

        private static Label NewWideLabel(string text)
        {
            return new Label
            {
                Text = text,
                AutoSize = false,
                Width = 62,
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

        private void BrowseReferenceImage()
        {
            OpenFileDialog dialog = new OpenFileDialog();
            dialog.Title = "选择 WinCC 参考图或界面截图";
            dialog.Filter = "Image files (*.png;*.jpg;*.jpeg;*.bmp;*.gif)|*.png;*.jpg;*.jpeg;*.bmp;*.gif|All files (*.*)|*.*";
            dialog.InitialDirectory = Environment.GetFolderPath(Environment.SpecialFolder.MyPictures);
            if (dialog.ShowDialog(this) == DialogResult.OK)
            {
                referenceImageBox.Text = dialog.FileName;
                LoadReferencePreview(dialog.FileName);
                SelectCombo(imageWorkflowBox, "图生图/参考图");
                SelectCombo(workflowSelectBox, "WinCC参考图复刻");
                ApplyWorkflowDefaults(false);
            }
        }

        private void LoadReferencePreview(string path)
        {
            try
            {
                if (referencePreviewBox.Image != null)
                {
                    Image old = referencePreviewBox.Image;
                    referencePreviewBox.Image = null;
                    old.Dispose();
                }

                using (FileStream stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
                using (Image loaded = Image.FromStream(stream))
                {
                    referencePreviewBox.Image = new Bitmap(loaded);
                }

                if (mainTabs.TabPages.Count >= 5)
                {
                    mainTabs.SelectedIndex = 4;
                }
                statusLabel.Text = "参考图已加载";
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "参考图加载失败", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }

        private void ApplyWorkflowDefaults(bool inferFromTextOnly)
        {
            if (applyingWorkflowDefaults)
            {
                return;
            }

            try
            {
                applyingWorkflowDefaults = true;
                string request = requestBox.Text ?? "";
                string workflow = Convert.ToString(workflowSelectBox.SelectedItem);
                string inferred = InferWorkflow(request, workflow);

                if (!inferFromTextOnly || workflow == "自动选择")
                {
                    SelectCombo(workflowSelectBox, inferred);
                }

                bool hasReferenceImage = File.Exists(referenceImageBox.Text);
                bool winccVisual = inferred.IndexOf("WinCC", StringComparison.OrdinalIgnoreCase) >= 0 || ContainsAny(request, new string[] { "画面", "界面", "hmi", "wincc", "参考图", "截图", "复刻" });
                bool lad = inferred.IndexOf("LAD", StringComparison.OrdinalIgnoreCase) >= 0 || ContainsAny(request, new string[] { "lad", "梯形图", "程序块", "db", "变量块" });

                if (winccVisual)
                {
                    SelectCombo(modelBox, "gpt-5");
                    SelectCombo(apiProviderBox, "Codex内置");
                    SelectCombo(imageWorkflowBox, hasReferenceImage ? "图生图/参考图" : "文生图");
                    SelectCombo(imageModelBox, "内置imagegen");
                    SelectCombo(imageQualityBox, "high");
                    SelectCombo(imageSizeBox, "1536x1024");
                    SelectCombo(componentStrategyBox, hasReferenceImage ? "自动匹配+自定义" : "Faceplate优先");
                    statusLabel.Text = hasReferenceImage ? "已按参考图复刻任务推荐模型" : "已按WinCC画面设计推荐模型";
                }
                else if (lad)
                {
                    SelectCombo(modelBox, "gpt-5-codex");
                    SelectCombo(imageWorkflowBox, "无图像");
                    SelectCombo(componentStrategyBox, "标准WinCC组件");
                    statusLabel.Text = "已按PLC/LAD任务推荐模型";
                }
                else if (ContainsAny(request, new string[] { "故障", "报错", "诊断", "openness" }))
                {
                    SelectCombo(modelBox, "gpt-5-codex");
                    SelectCombo(imageWorkflowBox, "无图像");
                    statusLabel.Text = "已按诊断任务推荐模型";
                }
            }
            finally
            {
                applyingWorkflowDefaults = false;
            }
        }

        private static string InferWorkflow(string request, string currentWorkflow)
        {
            if (!string.IsNullOrWhiteSpace(currentWorkflow) && currentWorkflow != "自动选择")
            {
                return currentWorkflow;
            }
            if (ContainsAny(request, new string[] { "参考图", "截图", "复刻", "图生图" }))
            {
                return "WinCC参考图复刻";
            }
            if (ContainsAny(request, new string[] { "wincc", "hmi", "画面", "界面", "faceplate", "报警画面", "趋势" }))
            {
                return "WinCC画面生成";
            }
            if (ContainsAny(request, new string[] { "lad", "梯形图", "程序块", "导入", "编译验证" }))
            {
                return "LAD编写与验证";
            }
            if (ContainsAny(request, new string[] { "db", "变量块", "数据块" }))
            {
                return "DB+程序块协同";
            }
            if (ContainsAny(request, new string[] { "故障", "报错", "诊断", "异常" }))
            {
                return "故障诊断";
            }
            return "读取项目并总结";
        }

        private static bool ContainsAny(string text, string[] needles)
        {
            string value = (text ?? "").ToLowerInvariant();
            foreach (string needle in needles)
            {
                if (value.IndexOf(needle.ToLowerInvariant(), StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    return true;
                }
            }
            return false;
        }

        private static void SelectCombo(ComboBox combo, string value)
        {
            if (combo.Items.Contains(value))
            {
                combo.SelectedItem = value;
            }
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
                ApplyWorkflowDefaults(false);
                string workflow = Convert.ToString(workflowSelectBox.SelectedItem);
                string referenceImage = referenceImageBox.Text.Trim();
                bool hasReferenceImage = File.Exists(referenceImage);
                StringBuilder content = new StringBuilder();
                content.AppendLine("# Codex PLC Task");
                content.AppendLine();
                content.AppendLine("Created: " + DateTime.Now.ToString("s"));
                content.AppendLine("Project: `" + root + "`");
                content.AppendLine("Model: `" + Convert.ToString(modelBox.SelectedItem) + "`");
                content.AppendLine("Workflow: `" + workflow + "`");
                content.AppendLine();
                content.AppendLine("## Model And API Routing");
                content.AppendLine();
                content.AppendLine("- Code model: `" + Convert.ToString(modelBox.SelectedItem) + "`");
                content.AppendLine("- API provider: `" + Convert.ToString(apiProviderBox.SelectedItem) + "`");
                content.AppendLine("- API base: `" + EmptyAsDefault(apiBaseBox.Text.Trim(), "default") + "`");
                content.AppendLine("- API key environment variable: `" + EmptyAsDefault(apiKeyEnvBox.Text.Trim(), "OPENAI_API_KEY") + "`");
                content.AppendLine("- Image workflow: `" + Convert.ToString(imageWorkflowBox.SelectedItem) + "`");
                content.AppendLine("- Image model: `" + Convert.ToString(imageModelBox.SelectedItem) + "`");
                content.AppendLine("- Image quality: `" + Convert.ToString(imageQualityBox.SelectedItem) + "`");
                content.AppendLine("- Image size: `" + Convert.ToString(imageSizeBox.SelectedItem) + "`");
                content.AppendLine("- Component strategy: `" + Convert.ToString(componentStrategyBox.SelectedItem) + "`");
                content.AppendLine("- Reference image: `" + (hasReferenceImage ? referenceImage : "none") + "`");
                content.AppendLine();
                content.AppendLine("## User Request");
                content.AppendLine();
                content.AppendLine(requestBox.Text.Trim());
                content.AppendLine();
                if (workflow.IndexOf("WinCC", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    content.AppendLine("## WinCC Visual Design Workflow");
                    content.AppendLine();
                    content.AppendLine(BuildWinccVisualWorkflow(hasReferenceImage));
                    content.AppendLine();
                    content.AppendLine("## Image Prompt Spec");
                    content.AppendLine();
                    content.AppendLine("```text");
                    content.AppendLine(BuildImagePromptSpec(hasReferenceImage));
                    content.AppendLine("```");
                    content.AppendLine();
                    content.AppendLine("## Component Mapping Plan");
                    content.AppendLine();
                    content.AppendLine(BuildComponentMappingPlan());
                    content.AppendLine();
                }
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
                content.AppendLine("3. For WinCC visual tasks, first produce a screen map and component/tag contract, then generate or update screens through Openness/SiVArc where available.");
                content.AppendLine("4. Use `write-cycle` on a cloned project before applying PLC-side generated LAD XML to the real project.");
                File.WriteAllText(path, content.ToString(), Encoding.UTF8);
                chatBox.AppendText(Environment.NewLine + "用户任务：" + requestBox.Text.Trim() + Environment.NewLine);
                chatBox.AppendText("模型：" + Convert.ToString(modelBox.SelectedItem) + "    工作流：" + workflow + "    图像：" + Convert.ToString(imageWorkflowBox.SelectedItem) + Environment.NewLine);
                if (hasReferenceImage)
                {
                    chatBox.AppendText("参考图：" + referenceImage + Environment.NewLine);
                }
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

        private static string EmptyAsDefault(string value, string fallback)
        {
            return string.IsNullOrWhiteSpace(value) ? fallback : value;
        }

        private string BuildWinccVisualWorkflow(bool hasReferenceImage)
        {
            StringBuilder builder = new StringBuilder();
            builder.AppendLine("1. Identify WinCC flavor: Advanced, Unified engineering, Unified runtime, or SiVArc.");
            builder.AppendLine("2. Read PLC/HMI contracts first: DB names, HMI tags, alarms, faceplates, and existing screen map.");
            if (hasReferenceImage)
            {
                builder.AppendLine("3. Analyze the reference image for layout zones, palette, typography, navigation style, state colors, and component density.");
                builder.AppendLine("4. Recreate the operator-facing composition as WinCC-native screens and faceplates, keeping the reference image as the visual target.");
            }
            else
            {
                builder.AppendLine("3. Generate a visual concept from the text description, then convert it into a WinCC-native screen map.");
                builder.AppendLine("4. Use image output as design proof, not as the final HMI implementation.");
            }
            builder.AppendLine("5. Map visual elements to WinCC components: indicators, command buttons, alarm strips, trends, recipe fields, faceplates, and station panels.");
            builder.AppendLine("6. Prefer Openness or SiVArc for screen/tag generation; keep manual fallback notes if an API surface is unavailable.");
            builder.AppendLine("7. Review safety: command confirmation, disabled reasons, alarm visibility, user level, and PLC connection state.");
            builder.AppendLine("8. Compile or smoke-test the HMI project on a backup/clone before applying to the main project.");
            return builder.ToString();
        }

        private string BuildImagePromptSpec(bool hasReferenceImage)
        {
            StringBuilder builder = new StringBuilder();
            builder.AppendLine("Use case: ui-mockup");
            builder.AppendLine("Asset type: WinCC HMI screen design reference");
            builder.AppendLine("Primary request: " + requestBox.Text.Trim());
            builder.AppendLine("Input images: " + (hasReferenceImage ? "Image 1 is the visual reference to match for layout, spacing, color, and component hierarchy." : "none"));
            builder.AppendLine("Screen map: Overview, Manual, Automatic, Alarm, Trend, Parameter, Maintenance, Diagnostics as needed.");
            builder.AppendLine("Style/medium: clean industrial HMI, soft gradient shell, clear card panels, restrained state colors.");
            builder.AppendLine("Composition/framing: operator-first scan, stable header, stable alarm/navigation strip, process flow matching the real machine.");
            builder.AppendLine("Color palette: neutral blue-gray/green-gray base, cyan or green running, amber warning, red fault, muted disabled state.");
            builder.AppendLine("Typography: readable Chinese + English labels, consistent title and object sizes.");
            builder.AppendLine("Constraints: final implementation must use WinCC-native components, tags, faceplates, alarms, and navigation objects rather than a static screenshot.");
            builder.AppendLine("Avoid: decorative-only dashboards, unreadable tiny text, color-only status, unsafe reset/home/recipe buttons without confirmation.");
            return builder.ToString();
        }

        private string BuildComponentMappingPlan()
        {
            StringBuilder builder = new StringBuilder();
            builder.AppendLine("- Screen shell: header with machine name, mode, PLC connection, user level, and time.");
            builder.AppendLine("- Navigation: Overview, Manual, Automatic, Alarm, Trend, Parameter, Maintenance, Diagnostics.");
            builder.AppendLine("- Station cards: state, command, feedback, interlock, fault, maintenance note.");
            builder.AppendLine("- Device components: `FP_Motor_电机`, `FP_Cylinder_气缸`, `FP_Drive_变频器`, `FP_Station_工位` when the PLC tags support them.");
            builder.AppendLine("- Alarm strip: active alarm, warning, first-out hint, acknowledgement/reset guidance.");
            builder.AppendLine("- Trends and parameters: bind only to reviewed DB members; show engineering limits and write authority.");
            builder.AppendLine("- Custom design components: create only when standard WinCC components or faceplates cannot match the reference layout cleanly.");
            builder.AppendLine("- Naming: bilingual screen/object/tag names aligned with PLC DB and UDT contracts.");
            return builder.ToString();
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

    internal sealed class DarkMenuRenderer : ToolStripProfessionalRenderer
    {
        public DarkMenuRenderer() : base(new DarkMenuColorTable())
        {
        }

        protected override void OnRenderMenuItemBackground(ToolStripItemRenderEventArgs e)
        {
            Rectangle rect = new Rectangle(Point.Empty, e.Item.Size);
            Color fill = e.Item.Selected ? Color.FromArgb(70, 56, 39) : Color.FromArgb(37, 39, 42);
            using (SolidBrush brush = new SolidBrush(fill))
            {
                e.Graphics.FillRectangle(brush, rect);
            }
        }

        protected override void OnRenderToolStripBorder(ToolStripRenderEventArgs e)
        {
            using (Pen pen = new Pen(Color.FromArgb(62, 67, 72)))
            {
                e.Graphics.DrawRectangle(pen, new Rectangle(0, 0, e.ToolStrip.Width - 1, e.ToolStrip.Height - 1));
            }
        }

        protected override void OnRenderSeparator(ToolStripSeparatorRenderEventArgs e)
        {
            using (Pen pen = new Pen(Color.FromArgb(58, 63, 68)))
            {
                int y = e.Item.Height / 2;
                e.Graphics.DrawLine(pen, 8, y, e.Item.Width - 8, y);
            }
        }
    }

    internal sealed class DarkMenuColorTable : ProfessionalColorTable
    {
        public override Color MenuItemSelected { get { return Color.FromArgb(70, 56, 39); } }
        public override Color MenuItemBorder { get { return Color.FromArgb(110, 82, 46); } }
        public override Color MenuBorder { get { return Color.FromArgb(62, 67, 72); } }
        public override Color ToolStripDropDownBackground { get { return Color.FromArgb(38, 42, 46); } }
        public override Color ImageMarginGradientBegin { get { return Color.FromArgb(38, 42, 46); } }
        public override Color ImageMarginGradientMiddle { get { return Color.FromArgb(38, 42, 46); } }
        public override Color ImageMarginGradientEnd { get { return Color.FromArgb(38, 42, 46); } }
        public override Color ToolStripGradientBegin { get { return Color.FromArgb(37, 39, 42); } }
        public override Color ToolStripGradientMiddle { get { return Color.FromArgb(37, 39, 42); } }
        public override Color ToolStripGradientEnd { get { return Color.FromArgb(37, 39, 42); } }
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
