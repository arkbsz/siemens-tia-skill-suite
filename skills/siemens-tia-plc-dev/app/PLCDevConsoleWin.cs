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
using System.Xml;

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
        private readonly RichTextBox planBox = new RichTextBox();
        private readonly RichTextBox diffBox = new RichTextBox();
        private readonly RichTextBox validationBox = new RichTextBox();
        private readonly RichTextBox contextBox = new RichTextBox();
        private readonly RichTextBox knowledgeBox = new RichTextBox();
        private readonly RichTextBox capabilityBox = new RichTextBox();
        private readonly RichTextBox ladSpecBox = new RichTextBox();
        private readonly TextBox requestBox = new TextBox();
        private readonly TextBox ladNetworkIndexBox = new TextBox();
        private readonly TextBox ladTitleBox = new TextBox();
        private readonly TextBox ladCommentBox = new TextBox();
        private readonly ComboBox ladConditionKindBox = new ComboBox();
        private readonly TextBox ladConditionLeftBox = new TextBox();
        private readonly TextBox ladConditionRightBox = new TextBox();
        private readonly TextBox ladConditionSourceTypeBox = new TextBox();
        private readonly ListBox ladConditionList = new ListBox();
        private readonly ComboBox ladActionKindBox = new ComboBox();
        private readonly TextBox ladActionTargetBox = new TextBox();
        private readonly TextBox ladActionInstanceBox = new TextBox();
        private readonly TextBox ladActionPtBox = new TextBox();
        private readonly ListBox ladActionList = new ListBox();
        private readonly Label ladEditorStatusLabel = new Label();
        private readonly Label statusLabel = new Label();
        private readonly Label projectBadge = new Label();
        private readonly MenuStrip mainMenu = new MenuStrip();
        private readonly ComboBox modelBox = new ComboBox();
        private readonly ComboBox workflowSelectBox = new ComboBox();
        private readonly ComboBox quickModelBox = new ComboBox();
        private readonly ComboBox quickWorkflowBox = new ComboBox();
        private readonly ComboBox routingModeBox = new ComboBox();
        private readonly ComboBox platformBox = new ComboBox();
        private readonly ComboBox quickRoutingModeBox = new ComboBox();
        private readonly ComboBox quickPlatformBox = new ComboBox();
        private readonly ComboBox agentBox = new ComboBox();
        private readonly ComboBox agentSandboxBox = new ComboBox();
        private readonly CheckBox agentSearchBox = new CheckBox();
        private readonly ComboBox languagePreferenceBox = new ComboBox();
        private readonly ComboBox tiaSessionModeBox = new ComboBox();
        private readonly ComboBox safetyModeBox = new ComboBox();
        private readonly ComboBox timeoutSecondsBox = new ComboBox();
        private readonly ComboBox apiProviderBox = new ComboBox();
        private readonly ComboBox imageWorkflowBox = new ComboBox();
        private readonly ComboBox imageModelBox = new ComboBox();
        private readonly ComboBox imageQualityBox = new ComboBox();
        private readonly ComboBox imageSizeBox = new ComboBox();
        private readonly ComboBox componentStrategyBox = new ComboBox();
        private readonly ComboBox winccFlavorBox = new ComboBox();
        private readonly ComboBox winccPluginPolicyBox = new ComboBox();
        private readonly ComboBox fontBox = new ComboBox();
        private readonly ComboBox fontSizeBox = new ComboBox();
        private readonly TextBox apiBaseBox = new TextBox();
        private readonly TextBox apiKeyEnvBox = new TextBox();
        private readonly TextBox codexCommandBox = new TextBox();
        private readonly TextBox claudeCommandBox = new TextBox();
        private readonly TextBox traeCommandBox = new TextBox();
        private readonly TextBox qoderCommandBox = new TextBox();
        private readonly TextBox traeProviderBox = new TextBox();
        private readonly TextBox referenceImageBox = new TextBox();
        private readonly TextBox winccGraphqlUrlBox = new TextBox();
        private readonly TextBox tiaMcpPathBox = new TextBox();
        private readonly TextBox tiaV20UnifiedMcpPathBox = new TextBox();
        private readonly TextBox tiaOpennessManagerPathBox = new TextBox();
        private readonly TextBox showScriptsPathBox = new TextBox();
        private readonly TextBox runtimeMcpPathBox = new TextBox();
        private readonly TextBox tiaViewerPathBox = new TextBox();
        private readonly Label agentAttachmentLabel = new Label();
        private readonly Label platformStatusLabel = new Label();
        private readonly Button sendAgentButton = new Button();
        private readonly Button stopAgentButton = new Button();
        private readonly CheckBox editPreviewBox = new CheckBox();
        private readonly PictureBox referencePreviewBox = new PictureBox();
        private readonly TabControl mainTabs = new TabControl();
        private readonly Panel scrollHost = new Panel();
        private readonly Panel scrollContent = new Panel();
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
        private string currentPreviewPath = "";
        private Process currentProcess;
        private Process agentProcess;
        private string agentThreadId = "";
        private string agentSessionPlatform = "";
        private string activePlatformName = "";
        private string activePlatformModel = "";
        private string agentStdoutPath = "";
        private string agentStderrPath = "";
        private readonly List<string> agentAttachments = new List<string>();
        private bool applyingWorkflowDefaults;
        private bool synchronizingSettings;
        private bool loadingWorkflowConfig;
        private bool workflowAutoMode = true;
        private string workflowConfigPath = "";
        private string currentLadSpecPath = "";
        private string currentLadGeneratedXmlPath = "";

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
                // Wait until the form handle exists before probing the current TIA session.
                Shown += delegate { AutoLoadCurrentTiaProject(false); };
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
            TableLayoutPanel formLayout = new TableLayoutPanel();
            formLayout.Dock = DockStyle.Fill;
            formLayout.Margin = new Padding(0);
            formLayout.Padding = new Padding(0);
            formLayout.ColumnCount = 1;
            formLayout.RowCount = 3;
            formLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            formLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 32));
            formLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
            formLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 28));
            Controls.Add(formLayout);

            BuildMainMenu();
            mainMenu.Margin = new Padding(0);
            formLayout.Controls.Add(mainMenu, 0, 0);
            MainMenuStrip = mainMenu;

            Panel bottom = new Panel();
            bottom.Dock = DockStyle.Fill;
            bottom.Margin = new Padding(0);
            bottom.BackColor = Color.FromArgb(224, 231, 222);
            formLayout.Controls.Add(bottom, 0, 2);

            Label safety = new Label();
            safety.Text = "安全策略：读写分离 · 先克隆验证 · 不并发打开TIA工程 · 主工程写入前人工确认";
            safety.Dock = DockStyle.Fill;
            safety.TextAlign = ContentAlignment.MiddleLeft;
            safety.Padding = new Padding(16, 0, 0, 0);
            safety.ForeColor = MutedInk;
            bottom.Controls.Add(safety);

            scrollHost.Dock = DockStyle.Fill;
            scrollHost.AutoScroll = true;
            scrollHost.BackColor = Canvas;
            scrollHost.TabStop = true;
            scrollHost.Margin = new Padding(0);
            scrollHost.MouseEnter += delegate { scrollHost.Focus(); };
            scrollHost.MouseWheel += delegate (object sender, MouseEventArgs e) { ScrollHostByWheel(e); };
            formLayout.Controls.Add(scrollHost, 0, 1);

            scrollContent.Location = new Point(0, 0);
            scrollContent.BackColor = Canvas;
            scrollContent.MinimumSize = new Size(980, 760);
            scrollHost.Controls.Add(scrollContent);
            scrollHost.Resize += delegate { LayoutScrollableContent(); };

            TableLayoutPanel workspaceLayout = new TableLayoutPanel();
            workspaceLayout.Dock = DockStyle.Fill;
            workspaceLayout.Margin = new Padding(0);
            workspaceLayout.Padding = new Padding(0);
            workspaceLayout.ColumnCount = 1;
            workspaceLayout.RowCount = 2;
            workspaceLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            workspaceLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 76));
            workspaceLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
            scrollContent.Controls.Add(workspaceLayout);

            Panel top = new BannerPanel();
            top.Dock = DockStyle.Fill;
            top.Margin = new Padding(0);
            top.MinimumSize = new Size(0, 76);
            top.Padding = new Padding(18, 10, 18, 8);
            top.BackColor = Rail;
            workspaceLayout.Controls.Add(top, 0, 0);

            Label title = new Label();
            title.Text = "TIA PLC Dev";
            title.ForeColor = Color.White;
            title.Font = new Font("Bahnschrift SemiBold", 14F, FontStyle.Bold);
            title.AutoSize = true;
            title.Location = new Point(18, 20);
            title.BackColor = Color.Transparent;
            top.Controls.Add(title);

            projectPathBox.Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right;
            projectPathBox.Location = new Point(164, 17);
            projectPathBox.Width = 620;
            StyleInput(projectPathBox);
            top.Controls.Add(projectPathBox);

            Button autoButton = NewButton("读取当前TIA", Teal);
            autoButton.Anchor = AnchorStyles.Top | AnchorStyles.Right;
            autoButton.Location = new Point(800, 14);
            autoButton.Width = 120;
            autoButton.Click += delegate { AutoLoadCurrentTiaProject(); };
            top.Controls.Add(autoButton);

            Button browseButton = NewButton("浏览打开", Ink);
            browseButton.Anchor = AnchorStyles.Top | AnchorStyles.Right;
            browseButton.Location = new Point(928, 14);
            browseButton.Width = 106;
            browseButton.Click += delegate { BrowseProject(); };
            top.Controls.Add(browseButton);

            Button loadButton = NewButton("加载项目", Teal);
            loadButton.Anchor = AnchorStyles.Top | AnchorStyles.Right;
            loadButton.Location = new Point(1042, 14);
            loadButton.Width = 100;
            loadButton.Click += delegate { LoadProject(projectPathBox.Text); };
            top.Controls.Add(loadButton);

            projectBadge.Anchor = AnchorStyles.Top | AnchorStyles.Right;
            projectBadge.Text = "V16-V21";
            projectBadge.ForeColor = Color.FromArgb(28, 45, 42);
            projectBadge.BackColor = Gold;
            projectBadge.Font = new Font(Font.FontFamily, 9F, FontStyle.Bold);
            projectBadge.TextAlign = ContentAlignment.MiddleCenter;
            projectBadge.Location = new Point(1156, 17);
            projectBadge.Size = new Size(82, 28);
            top.Controls.Add(projectBadge);

            statusLabel.Anchor = AnchorStyles.Top | AnchorStyles.Left;
            statusLabel.ForeColor = Color.FromArgb(244, 202, 145);
            statusLabel.AutoSize = false;
            statusLabel.AutoEllipsis = true;
            statusLabel.Location = new Point(1252, 22);
            statusLabel.BackColor = Color.Transparent;
            top.Controls.Add(statusLabel);
            top.Resize += delegate { LayoutHeader(top, title, projectPathBox, autoButton, browseButton, loadButton, projectBadge, statusLabel); };

            SplitContainer outer = new SplitContainer();
            outerSplitter = outer;
            outer.Dock = DockStyle.Fill;
            outer.SplitterWidth = 6;
            outer.Panel1MinSize = 1;
            outer.Panel2MinSize = 1;
            outer.BackColor = Canvas;
            outer.Panel1.Padding = new Padding(12, 14, 6, 14);
            outer.Panel2.Padding = new Padding(6, 14, 12, 14);
            outer.Margin = new Padding(0);
            workspaceLayout.Controls.Add(outer, 0, 1);

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
            mainLayout.RowCount = 3;
            mainLayout.ColumnCount = 1;
            mainLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 58));
            mainLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 58));
            mainLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
            mainBox.Controls.Add(mainLayout);

            FlowLayoutPanel commandBar = new FlowLayoutPanel();
            commandBar.Dock = DockStyle.Fill;
            commandBar.WrapContents = false;
            commandBar.AutoScroll = true;
            commandBar.Padding = new Padding(12, 10, 12, 6);
            commandBar.BackColor = Card;
            commandBar.Controls.Add(CommandButton("Doctor 检查", "doctor", Ink));
            commandBar.Controls.Add(CommandButton("快速读取", "read-cycle-skip", Teal));
            commandBar.Controls.Add(CommandButton("完整导出", "read-cycle-full", Orange));
            commandBar.Controls.Add(CommandButton("列程序块", "list-blocks", Ink));
            commandBar.Controls.Add(CommandButton("LAD预览", "lad-preview", Teal));
            commandBar.Controls.Add(CommandButton("项目模型", "project-model", Teal));
            commandBar.Controls.Add(CommandButton("知识检索", "knowledge-pack", Teal));
            commandBar.Controls.Add(CommandButton("能力矩阵", "capability-map", Teal));
            commandBar.Controls.Add(CommandButton("指令库", "plc-instruction-cookbook", Teal));
            commandBar.Controls.Add(CommandButton("自动流水线", "agent-pipeline", Gold));
            commandBar.Controls.Add(CommandButton("PLC改动包", "plc-change-package", Gold));
            commandBar.Controls.Add(CommandButton("指令方案", "plc-instruction-plan", Teal));
            commandBar.Controls.Add(CommandButton("WinCC读取", "wincc-read-cycle", Teal));
            commandBar.Controls.Add(CommandButton("WinCC克隆应用", "wincc-apply-clone", Orange));
            commandBar.Controls.Add(CommandButton("WinCC插件", "wincc-plugins", Teal));
            commandBar.Controls.Add(CommandButton("WinCC方案", "wincc-visual-package", Orange));
            commandBar.Controls.Add(CommandButton("组件蓝图", "wincc-component-blueprints", Orange));
            commandBar.Controls.Add(CommandButton("WinCC工程", "wincc-engineering-scaffold", Orange));
            commandBar.Controls.Add(CommandButton("WinCC实现", "wincc-openness-implementation", Orange));
            commandBar.Controls.Add(CommandButton("仿真包", "simulation-package", Teal));
            commandBar.Controls.Add(CommandButton("仿真回放", "simulation-replay", Teal));
            commandBar.Controls.Add(CommandButton("任务编排", "agent-plan", Gold));
            commandBar.Controls.Add(CommandButton("执行队列", "agent-queue", Teal));
            commandBar.Controls.Add(CommandButton("运行阶段", "queue-run-current", Gold));
            commandBar.Controls.Add(CommandButton("审查包", "review-package", Ink));
            commandBar.Controls.Add(CommandButton("总览面板", "workbench-dashboard", Teal));
            editPreviewBox.Text = "编辑预览";
            editPreviewBox.AutoSize = true;
            editPreviewBox.Margin = new Padding(10, 8, 6, 4);
            editPreviewBox.ForeColor = Ink;
            editPreviewBox.CheckedChanged += delegate { TogglePreviewEditing(); };
            commandBar.Controls.Add(editPreviewBox);
            Button savePreview = NewButton("保存文件", Gold);
            savePreview.ForeColor = Ink;
            savePreview.Width = 96;
            savePreview.Height = 34;
            savePreview.Margin = new Padding(6, 2, 6, 2);
            savePreview.Click += delegate { SaveCurrentPreviewFile(); };
            commandBar.Controls.Add(savePreview);
            mainLayout.Controls.Add(commandBar, 0, 0);

            TableLayoutPanel writePanel = new TableLayoutPanel();
            writePanel.Dock = DockStyle.Fill;
            writePanel.ColumnCount = 6;
            writePanel.RowCount = 1;
            writePanel.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 82));
            writePanel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            writePanel.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 48));
            writePanel.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 132));
            writePanel.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 112));
            writePanel.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 142));
            writePanel.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
            writePanel.Padding = new Padding(12, 8, 12, 8);
            writePanel.BackColor = Card;
            StyleInput(inputXmlBox);
            StyleInput(plcNameBox);
            inputXmlBox.Dock = DockStyle.Fill;
            plcNameBox.Dock = DockStyle.Fill;
            writePanel.Controls.Add(new Label { Text = "LAD XML", Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleLeft, ForeColor = MutedInk }, 0, 0);
            writePanel.Controls.Add(inputXmlBox, 1, 0);
            writePanel.Controls.Add(new Label { Text = "PLC", Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleCenter, ForeColor = MutedInk }, 2, 0);
            writePanel.Controls.Add(plcNameBox, 3, 0);
            Button refresh = NewButton("刷新 runs", Teal);
            refresh.Dock = DockStyle.Fill;
            refresh.Click += delegate { RefreshRuns(); };
            writePanel.Controls.Add(refresh, 4, 0);
            Button writeCycle = NewButton("克隆验证 LAD", Orange);
            writeCycle.Dock = DockStyle.Fill;
            writeCycle.Click += delegate { StartCommand("write-cycle"); };
            writePanel.Controls.Add(writeCycle, 5, 0);
            mainLayout.Controls.Add(writePanel, 0, 1);

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
            chatBox.Text = "内置 Agent 对话\n\n选择 Agent、模型和工作流后，可在下方直接发送消息或上传文件。PLC/WinCC 工程写入仍遵循备份优先、克隆编译验证和主工程人工确认策略。\n";

            planBox.Dock = DockStyle.Fill;
            planBox.ReadOnly = true;
            planBox.BorderStyle = BorderStyle.None;
            planBox.BackColor = Color.FromArgb(250, 248, 238);
            planBox.ForeColor = Ink;
            planBox.Font = new Font("Microsoft YaHei UI", 9.2F);
            planBox.Text = "任务编排\n\n这里会显示本地工作台生成的 PLC/WinCC Agent 开发计划：阶段、工具、产物、验证门槛和安全边界。";

            diffBox.Dock = DockStyle.Fill;
            diffBox.ReadOnly = true;
            diffBox.BorderStyle = BorderStyle.None;
            diffBox.BackColor = CodeBack;
            diffBox.ForeColor = CodeFore;
            diffBox.Font = new Font("Cascadia Code", 9F);
            diffBox.Text = "审查 / Diff\n\n这里会显示 Git diff、审查包摘要和即将导入的 PLC/WinCC 变更。";

            validationBox.Dock = DockStyle.Fill;
            validationBox.ReadOnly = true;
            validationBox.BorderStyle = BorderStyle.None;
            validationBox.BackColor = Color.FromArgb(246, 250, 242);
            validationBox.ForeColor = Ink;
            validationBox.Font = new Font("Microsoft YaHei UI", 9.2F);
            validationBox.Text = "验证面板\n\n这里会显示最新 read-cycle、write-cycle、导入就绪、队列健康和安全门禁状态。";

            contextBox.Dock = DockStyle.Fill;
            contextBox.ReadOnly = true;
            contextBox.BorderStyle = BorderStyle.None;
            contextBox.BackColor = Color.FromArgb(244, 249, 247);
            contextBox.ForeColor = Ink;
            contextBox.Font = new Font("Microsoft YaHei UI", 9.2F);
            contextBox.Text = "项目模型\n\n这里会显示可供 Agent 直接使用的项目对象模型：TIA版本、程序块、DB、WinCC包、指令方案、队列、风险和关键工程文件索引。";

            knowledgeBox.Dock = DockStyle.Fill;
            knowledgeBox.ReadOnly = true;
            knowledgeBox.BorderStyle = BorderStyle.None;
            knowledgeBox.BackColor = Color.FromArgb(250, 249, 241);
            knowledgeBox.ForeColor = Ink;
            knowledgeBox.Font = new Font("Microsoft YaHei UI", 9.2F);
            knowledgeBox.Text = "知识库\n\n这里会显示任务相关的官方文档、社区案例、插件路线、检索关键词和当前项目上下文绑定。优先官方资料，社区工具只作为审查后的适配参考。";

            capabilityBox.Dock = DockStyle.Fill;
            capabilityBox.ReadOnly = true;
            capabilityBox.BorderStyle = BorderStyle.None;
            capabilityBox.BackColor = Color.FromArgb(244, 248, 242);
            capabilityBox.ForeColor = Ink;
            capabilityBox.Font = new Font("Microsoft YaHei UI", 9.2F);
            capabilityBox.Text = "能力矩阵\n\n这里会显示本地工作台替代 TIA Portal 原生编辑器的实际覆盖情况：已可用能力、半自动能力、仍需 TIA 原生界面的边界和下一步增强方向。";

            referencePreviewBox.Dock = DockStyle.Fill;
            referencePreviewBox.BackColor = Color.FromArgb(28, 47, 48);
            referencePreviewBox.BorderStyle = BorderStyle.None;
            referencePreviewBox.SizeMode = PictureBoxSizeMode.Zoom;

            mainTabs.Dock = DockStyle.Fill;
            mainTabs.Font = new Font("Microsoft YaHei UI", 9.6F, FontStyle.Bold);
            mainTabs.Appearance = TabAppearance.Normal;
            mainTabs.Controls.Add(NewTab("AI 对话", chatBox));
            mainTabs.Controls.Add(NewTab("任务编排", planBox));
            mainTabs.Controls.Add(NewTab("日志输出", jobBox));
            mainTabs.Controls.Add(NewTab("文件预览", previewBox));
            mainTabs.Controls.Add(NewTab("Runs", runList));
            mainTabs.Controls.Add(NewTab("审查/Diff", diffBox));
            mainTabs.Controls.Add(NewTab("验证面板", validationBox));
            mainTabs.Controls.Add(NewTab("项目模型", contextBox));
            mainTabs.Controls.Add(NewTab("知识库", knowledgeBox));
            mainTabs.Controls.Add(NewTab("能力矩阵", capabilityBox));
            mainTabs.Controls.Add(NewTab("参考图", referencePreviewBox));
            mainTabs.Controls.Add(NewTab("LAD结构编辑", BuildLadEditorPage()));
            mainLayout.Controls.Add(mainTabs, 0, 2);

            GroupBox aiInputBox = NewGroup("AI交互与工作流");
            aiInputBox.Dock = DockStyle.Fill;
            center.Panel2.Controls.Add(aiInputBox);

            TableLayoutPanel aiLayout = new TableLayoutPanel();
            aiLayout.Dock = DockStyle.Fill;
            aiLayout.RowCount = 3;
            aiLayout.ColumnCount = 1;
            aiLayout.Padding = new Padding(2, 0, 2, 2);
            aiLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 84));
            aiLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 42));
            aiLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
            aiInputBox.Controls.Add(aiLayout);

            TableLayoutPanel configGrid = new TableLayoutPanel();
            configGrid.Dock = DockStyle.Fill;
            configGrid.Margin = new Padding(0, 0, 0, 4);
            configGrid.Padding = new Padding(4, 3, 4, 3);
            configGrid.BackColor = CardSoft;
            configGrid.ColumnCount = 5;
            configGrid.RowCount = 2;
            for (int configColumn = 0; configColumn < 5; configColumn++)
            {
                configGrid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 20));
            }
            configGrid.RowStyles.Add(new RowStyle(SizeType.Percent, 50));
            configGrid.RowStyles.Add(new RowStyle(SizeType.Percent, 50));
            AddQuickSettingCell(configGrid, 0, 0, "路由", quickRoutingModeBox);
            AddQuickSettingCell(configGrid, 1, 0, "平台", quickPlatformBox);
            AddQuickSettingCell(configGrid, 2, 0, "智能体", agentBox);
            AddQuickSettingCell(configGrid, 3, 0, "模型", quickModelBox);
            AddQuickSettingCell(configGrid, 4, 0, "工作流", quickWorkflowBox);
            AddQuickSettingCell(configGrid, 0, 1, "语言", languagePreferenceBox);
            AddQuickSettingCell(configGrid, 1, 1, "TIA", tiaSessionModeBox);
            AddQuickSettingCell(configGrid, 2, 1, "安全", safetyModeBox);
            AddQuickSettingCell(configGrid, 3, 1, "超时", timeoutSecondsBox);

            TableLayoutPanel configActions = new TableLayoutPanel();
            configActions.Dock = DockStyle.Fill;
            configActions.Margin = new Padding(3, 2, 3, 2);
            configActions.ColumnCount = 2;
            configActions.RowCount = 1;
            configActions.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50));
            configActions.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50));
            Button saveConfigButton = NewButton("保存配置", Ink);
            StyleCompactButton(saveConfigButton);
            saveConfigButton.Click += delegate { SaveWorkflowConfig(true); };
            configActions.Controls.Add(saveConfigButton, 0, 0);
            Button viewConfigButton = NewButton("查看配置", Teal);
            StyleCompactButton(viewConfigButton);
            viewConfigButton.Click += delegate { ShowWorkflowConfig(); };
            configActions.Controls.Add(viewConfigButton, 1, 0);
            configGrid.Controls.Add(configActions, 4, 1);
            aiLayout.Controls.Add(configGrid, 0, 0);

            TableLayoutPanel attachmentBar = new TableLayoutPanel();
            attachmentBar.Dock = DockStyle.Fill;
            attachmentBar.Margin = new Padding(0);
            attachmentBar.Padding = new Padding(4, 2, 4, 2);
            attachmentBar.BackColor = Color.FromArgb(238, 243, 235);
            attachmentBar.ColumnCount = 6;
            attachmentBar.RowCount = 1;
            attachmentBar.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 86));
            attachmentBar.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 86));
            attachmentBar.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 112));
            attachmentBar.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 104));
            attachmentBar.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 62));
            attachmentBar.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 38));
            Button addAttachmentButton = NewButton("上传文件", Teal);
            StyleCompactButton(addAttachmentButton);
            addAttachmentButton.Click += delegate { BrowseAgentAttachments(); };
            attachmentBar.Controls.Add(addAttachmentButton, 0, 0);
            Button clearAttachmentButton = NewButton("清空附件", Ink);
            StyleCompactButton(clearAttachmentButton);
            clearAttachmentButton.Click += delegate { ClearAgentAttachments(); };
            attachmentBar.Controls.Add(clearAttachmentButton, 1, 0);
            Button scanPluginsButton = NewButton("WinCC插件", Orange);
            StyleCompactButton(scanPluginsButton);
            scanPluginsButton.Click += delegate { StartCommand("wincc-plugins"); };
            attachmentBar.Controls.Add(scanPluginsButton, 2, 0);
            Button probePlatformsButton = NewButton("检测平台", Teal);
            StyleCompactButton(probePlatformsButton);
            probePlatformsButton.Click += delegate { StartCommand("probe-ai-platforms"); };
            attachmentBar.Controls.Add(probePlatformsButton, 3, 0);
            agentAttachmentLabel.AutoSize = false;
            agentAttachmentLabel.Dock = DockStyle.Fill;
            agentAttachmentLabel.Margin = new Padding(8, 0, 4, 0);
            agentAttachmentLabel.TextAlign = ContentAlignment.MiddleLeft;
            agentAttachmentLabel.AutoEllipsis = true;
            agentAttachmentLabel.ForeColor = MutedInk;
            agentAttachmentLabel.Text = "附件：无，可上传图片、PDF、文档、源码或导出 XML";
            attachmentBar.Controls.Add(agentAttachmentLabel, 4, 0);
            platformStatusLabel.AutoSize = false;
            platformStatusLabel.Dock = DockStyle.Fill;
            platformStatusLabel.Margin = new Padding(4, 0, 4, 0);
            platformStatusLabel.TextAlign = ContentAlignment.MiddleLeft;
            platformStatusLabel.AutoEllipsis = true;
            platformStatusLabel.ForeColor = Teal;
            platformStatusLabel.Text = "平台：等待检测";
            attachmentBar.Controls.Add(platformStatusLabel, 5, 0);
            aiLayout.Controls.Add(attachmentBar, 0, 1);

            TableLayoutPanel inputLayout = new TableLayoutPanel();
            inputLayout.Dock = DockStyle.Fill;
            inputLayout.ColumnCount = 2;
            inputLayout.RowCount = 1;
            inputLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            inputLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 176));
            inputLayout.Padding = new Padding(0, 4, 0, 0);
            aiLayout.Controls.Add(inputLayout, 0, 2);

            requestBox.Dock = DockStyle.Fill;
            requestBox.Margin = new Padding(4, 2, 6, 4);
            requestBox.Multiline = true;
            requestBox.ScrollBars = ScrollBars.Vertical;
            StyleInput(requestBox);
            requestBox.Text = "例如：读取当前项目并检查电机正反转 LAD、DB 变量和 WinCC 手动画面的联锁是否完整，然后在克隆工程中修复并编译验证。";
            inputLayout.Controls.Add(requestBox, 0, 0);

            Panel actionRail = new Panel();
            actionRail.Dock = DockStyle.Fill;
            actionRail.Margin = new Padding(0, 0, 2, 4);
            actionRail.Padding = new Padding(4);
            actionRail.BackColor = CardSoft;

            TableLayoutPanel agentActions = new TableLayoutPanel();
            agentActions.Dock = DockStyle.Top;
            agentActions.Height = 80;
            agentActions.ColumnCount = 2;
            agentActions.RowCount = 2;
            agentActions.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50));
            agentActions.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50));
            agentActions.RowStyles.Add(new RowStyle(SizeType.Absolute, 38));
            agentActions.RowStyles.Add(new RowStyle(SizeType.Absolute, 38));
            sendAgentButton.Text = "发送";
            StyleActionButton(sendAgentButton, Teal);
            sendAgentButton.Click += delegate { SendAgentMessage(); };
            agentActions.Controls.Add(sendAgentButton, 0, 0);
            stopAgentButton.Text = "停止";
            StyleActionButton(stopAgentButton, Orange);
            stopAgentButton.Enabled = false;
            stopAgentButton.Click += delegate { StopAgent(); };
            agentActions.Controls.Add(stopAgentButton, 1, 0);
            Button newSessionButton = NewButton("新会话", Ink);
            newSessionButton.Dock = DockStyle.Fill;
            newSessionButton.Margin = new Padding(4);
            newSessionButton.Click += delegate { NewAgentSession(); };
            agentActions.Controls.Add(newSessionButton, 0, 1);
            Button promptButton = NewButton("任务草稿", Gold);
            promptButton.ForeColor = Ink;
            promptButton.Dock = DockStyle.Fill;
            promptButton.Margin = new Padding(4);
            promptButton.Click += delegate { CreateAiPrompt(); };
            agentActions.Controls.Add(promptButton, 1, 1);
            actionRail.Controls.Add(agentActions);

            Label actionHint = new Label();
            actionHint.Dock = DockStyle.Fill;
            actionHint.Padding = new Padding(8, 88, 8, 6);
            actionHint.TextAlign = ContentAlignment.TopLeft;
            actionHint.ForeColor = MutedInk;
            actionHint.Font = new Font("Microsoft YaHei UI", 8.5F);
            actionHint.Text = "Ctrl+Enter 发送\n平台、模型和工作流会随配置保存。";
            actionRail.Controls.Add(actionHint);
            actionHint.BringToFront();
            agentActions.BringToFront();
            inputLayout.Controls.Add(actionRail, 1, 0);

            tailTimer.Interval = 1200;
            tailTimer.Tick += delegate { RefreshCurrentJobTail(); };

            Shown += delegate
            {
                LayoutScrollableContent();
                LayoutHeader(top, title, projectPathBox, autoButton, browseButton, loadButton, projectBadge, statusLabel);
                SafeConfigureSplitter(outer, 240, 560, 360);
                SafeConfigureSplitter(center, 300, 240, Math.Max(340, center.Height - 310));
            };
        }

        private Control BuildLadEditorPage()
        {
            TableLayoutPanel page = new TableLayoutPanel();
            page.Dock = DockStyle.Fill;
            page.BackColor = Canvas;
            page.Padding = new Padding(8);
            page.ColumnCount = 1;
            page.RowCount = 3;
            page.RowStyles.Add(new RowStyle(SizeType.Absolute, 48));
            page.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
            page.RowStyles.Add(new RowStyle(SizeType.Absolute, 24));

            FlowLayoutPanel toolbar = new FlowLayoutPanel();
            toolbar.Dock = DockStyle.Fill;
            toolbar.WrapContents = false;
            toolbar.AutoScroll = true;
            toolbar.BackColor = CardSoft;
            toolbar.Padding = new Padding(6, 7, 6, 5);

            toolbar.Controls.Add(LadEditorLabel("网络"));
            ladNetworkIndexBox.Width = 48;
            StyleInput(ladNetworkIndexBox);
            ladNetworkIndexBox.Text = "1";
            toolbar.Controls.Add(ladNetworkIndexBox);
            toolbar.Controls.Add(LadEditorLabel("标题"));
            ladTitleBox.Width = 170;
            StyleInput(ladTitleBox);
            ladTitleBox.Text = "LAD network";
            toolbar.Controls.Add(ladTitleBox);
            toolbar.Controls.Add(LadEditorLabel("注释"));
            ladCommentBox.Width = 260;
            StyleInput(ladCommentBox);
            toolbar.Controls.Add(ladCommentBox);

            Button ladReadButton = NewButton("从XML读取", Teal);
            ladReadButton.Width = 100;
            ladReadButton.Height = 30;
            ladReadButton.Margin = new Padding(5, 1, 3, 1);
            ladReadButton.Click += delegate { LoadLadNetworkFromXml(); };
            toolbar.Controls.Add(ladReadButton);
            Button ladTemplateButton = NewButton("载入模板", Ink);
            ladTemplateButton.Width = 82;
            ladTemplateButton.Height = 30;
            ladTemplateButton.Margin = new Padding(3, 1, 3, 1);
            ladTemplateButton.Click += delegate { StartCommand("lad-scaffold"); };
            toolbar.Controls.Add(ladTemplateButton);
            Button ladSyncButton = NewButton("结构生成JSON", Teal);
            ladSyncButton.Width = 106;
            ladSyncButton.Height = 30;
            ladSyncButton.Margin = new Padding(3, 1, 3, 1);
            ladSyncButton.Click += delegate { SyncLadSpecFromEditor(); };
            toolbar.Controls.Add(ladSyncButton);
            Button ladLoadJsonButton = NewButton("JSON读入结构", Teal);
            ladLoadJsonButton.Width = 106;
            ladLoadJsonButton.Height = 30;
            ladLoadJsonButton.Margin = new Padding(3, 1, 3, 1);
            ladLoadJsonButton.Click += delegate { LoadLadEditorFromSpec(); };
            toolbar.Controls.Add(ladLoadJsonButton);
            Button ladSaveButton = NewButton("保存JSON", Gold);
            ladSaveButton.ForeColor = Ink;
            ladSaveButton.Width = 76;
            ladSaveButton.Height = 30;
            ladSaveButton.Margin = new Padding(3, 1, 3, 1);
            ladSaveButton.Click += delegate { SaveLadSpecToDisk(); };
            toolbar.Controls.Add(ladSaveButton);
            Button ladGenerateButton = NewButton("生成XML", Orange);
            ladGenerateButton.Width = 78;
            ladGenerateButton.Height = 30;
            ladGenerateButton.Margin = new Padding(3, 1, 3, 1);
            ladGenerateButton.Click += delegate { GenerateLadXml(); };
            toolbar.Controls.Add(ladGenerateButton);
            Button ladValidateButton = NewButton("校验XML", Ink);
            ladValidateButton.Width = 78;
            ladValidateButton.Height = 30;
            ladValidateButton.Margin = new Padding(3, 1, 3, 1);
            ladValidateButton.Click += delegate { StartCommand("lad-validate"); };
            toolbar.Controls.Add(ladValidateButton);
            Button ladVerifyButton = NewButton("克隆验证", Orange);
            ladVerifyButton.Width = 86;
            ladVerifyButton.Height = 30;
            ladVerifyButton.Margin = new Padding(3, 1, 3, 1);
            ladVerifyButton.Click += delegate { VerifyLadEditorOutput(); };
            toolbar.Controls.Add(ladVerifyButton);
            page.Controls.Add(toolbar, 0, 0);

            SplitContainer editorSplitter = new SplitContainer();
            editorSplitter.Dock = DockStyle.Fill;
            editorSplitter.Orientation = Orientation.Vertical;
            editorSplitter.SplitterWidth = 7;
            // The tab has no client size while the form is being constructed.
            // Keep minimums small here; WinForms will otherwise throw before
            // the first layout pass. The editor remains resizable afterwards.
            editorSplitter.Panel1MinSize = 1;
            editorSplitter.Panel2MinSize = 1;
            editorSplitter.BackColor = Canvas;
            page.Controls.Add(editorSplitter, 0, 1);

            TableLayoutPanel structureLayout = new TableLayoutPanel();
            structureLayout.Dock = DockStyle.Fill;
            structureLayout.Padding = new Padding(2);
            structureLayout.ColumnCount = 1;
            structureLayout.RowCount = 2;
            structureLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 50));
            structureLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 50));
            editorSplitter.Panel1.Controls.Add(structureLayout);

            GroupBox conditionGroup = NewGroup("条件链 / Conditions");
            conditionGroup.Dock = DockStyle.Fill;
            TableLayoutPanel conditionLayout = new TableLayoutPanel();
            conditionLayout.Dock = DockStyle.Fill;
            conditionLayout.ColumnCount = 1;
            conditionLayout.RowCount = 2;
            conditionLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
            conditionLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 38));
            ladConditionList.Dock = DockStyle.Fill;
            ladConditionList.BorderStyle = BorderStyle.None;
            ladConditionList.BackColor = CardSoft;
            ladConditionList.ForeColor = Ink;
            ladConditionList.Font = new Font("Cascadia Mono", 9F);
            conditionLayout.Controls.Add(ladConditionList, 0, 0);

            FlowLayoutPanel conditionInput = new FlowLayoutPanel();
            conditionInput.Dock = DockStyle.Fill;
            conditionInput.WrapContents = false;
            conditionInput.AutoScroll = true;
            conditionInput.Padding = new Padding(0, 4, 0, 2);
            ConfigureCombo(ladConditionKindBox, new string[] { "NO", "NC", "P_EDGE", "N_EDGE", "EQ", "NE", "GE", "GT", "LE", "LT" }, "NO", 74);
            ladConditionLeftBox.Width = 142;
            ladConditionRightBox.Width = 122;
            ladConditionSourceTypeBox.Width = 72;
            StyleInput(ladConditionLeftBox);
            StyleInput(ladConditionRightBox);
            StyleInput(ladConditionSourceTypeBox);
            conditionInput.Controls.Add(ladConditionKindBox);
            conditionInput.Controls.Add(ladConditionLeftBox);
            conditionInput.Controls.Add(ladConditionRightBox);
            conditionInput.Controls.Add(ladConditionSourceTypeBox);
            Button addConditionButton = NewButton("+条件", Teal);
            addConditionButton.Width = 64;
            addConditionButton.Height = 28;
            addConditionButton.Margin = new Padding(3, 1, 2, 1);
            addConditionButton.Click += delegate { AddLadConditionFromFields(); };
            conditionInput.Controls.Add(addConditionButton);
            Button removeConditionButton = NewButton("-条件", Ink);
            removeConditionButton.Width = 64;
            removeConditionButton.Height = 28;
            removeConditionButton.Margin = new Padding(2, 1, 2, 1);
            removeConditionButton.Click += delegate { RemoveSelectedLadCondition(); };
            conditionInput.Controls.Add(removeConditionButton);
            conditionLayout.Controls.Add(conditionInput, 0, 1);
            conditionGroup.Controls.Add(conditionLayout);
            structureLayout.Controls.Add(conditionGroup, 0, 0);

            GroupBox actionGroup = NewGroup("动作链 / Actions");
            actionGroup.Dock = DockStyle.Fill;
            TableLayoutPanel actionLayout = new TableLayoutPanel();
            actionLayout.Dock = DockStyle.Fill;
            actionLayout.ColumnCount = 1;
            actionLayout.RowCount = 2;
            actionLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
            actionLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 38));
            ladActionList.Dock = DockStyle.Fill;
            ladActionList.BorderStyle = BorderStyle.None;
            ladActionList.BackColor = CardSoft;
            ladActionList.ForeColor = Ink;
            ladActionList.Font = new Font("Cascadia Mono", 9F);
            actionLayout.Controls.Add(ladActionList, 0, 0);

            FlowLayoutPanel actionInput = new FlowLayoutPanel();
            actionInput.Dock = DockStyle.Fill;
            actionInput.WrapContents = false;
            actionInput.AutoScroll = true;
            actionInput.Padding = new Padding(0, 4, 0, 2);
            ConfigureCombo(ladActionKindBox, new string[] { "COIL", "SET", "RESET", "TON", "TOF", "TP", "MOVE", "CTU", "CTD", "CTUD", "CALL" }, "COIL", 78);
            ladActionTargetBox.Width = 132;
            ladActionInstanceBox.Width = 132;
            ladActionPtBox.Width = 82;
            StyleInput(ladActionTargetBox);
            StyleInput(ladActionInstanceBox);
            StyleInput(ladActionPtBox);
            actionInput.Controls.Add(ladActionKindBox);
            actionInput.Controls.Add(ladActionTargetBox);
            actionInput.Controls.Add(ladActionInstanceBox);
            actionInput.Controls.Add(ladActionPtBox);
            Button addActionButton = NewButton("+动作", Teal);
            addActionButton.Width = 64;
            addActionButton.Height = 28;
            addActionButton.Margin = new Padding(3, 1, 2, 1);
            addActionButton.Click += delegate { AddLadActionFromFields(); };
            actionInput.Controls.Add(addActionButton);
            Button removeActionButton = NewButton("-动作", Ink);
            removeActionButton.Width = 64;
            removeActionButton.Height = 28;
            removeActionButton.Margin = new Padding(2, 1, 2, 1);
            removeActionButton.Click += delegate { RemoveSelectedLadAction(); };
            actionInput.Controls.Add(removeActionButton);
            actionLayout.Controls.Add(actionInput, 0, 1);
            actionGroup.Controls.Add(actionLayout);
            structureLayout.Controls.Add(actionGroup, 0, 1);

            GroupBox jsonGroup = NewGroup("自由规格 / LAD JSON");
            jsonGroup.Dock = DockStyle.Fill;
            ladSpecBox.Dock = DockStyle.Fill;
            ladSpecBox.Multiline = true;
            ladSpecBox.AcceptsTab = true;
            ladSpecBox.ScrollBars = RichTextBoxScrollBars.Both;
            ladSpecBox.WordWrap = false;
            ladSpecBox.BorderStyle = BorderStyle.None;
            ladSpecBox.BackColor = CodeBack;
            ladSpecBox.ForeColor = CodeFore;
            ladSpecBox.Font = new Font("Cascadia Code", 9.2F);
            ladSpecBox.Text = DefaultLadSpecJson();
            jsonGroup.Controls.Add(ladSpecBox);
            editorSplitter.Panel2.Controls.Add(jsonGroup);

            ladEditorStatusLabel.Dock = DockStyle.Fill;
            ladEditorStatusLabel.TextAlign = ContentAlignment.MiddleLeft;
            ladEditorStatusLabel.ForeColor = MutedInk;
            ladEditorStatusLabel.Padding = new Padding(8, 0, 0, 0);
            ladEditorStatusLabel.Text = "LAD编辑器：支持条件、定时器、线圈、置位/复位、MOVE、计数器和通用CALL；高级形状可直接编辑JSON。";
            page.Controls.Add(ladEditorStatusLabel, 0, 2);

            LoadLadEditorFromSpec();
            return page;
        }

        private static Label LadEditorLabel(string text)
        {
            Label label = new Label();
            label.Text = text;
            label.AutoSize = true;
            label.ForeColor = MutedInk;
            label.TextAlign = ContentAlignment.MiddleLeft;
            label.Margin = new Padding(3, 7, 2, 3);
            return label;
        }

        private static string DefaultLadSpecJson()
        {
            return "{\r\n" +
                "  \"title\": \"Motor start stop / 电机启停\",\r\n" +
                "  \"comment\": \"LAD结构化编辑器生成的网络\",\r\n" +
                "  \"conditions\": [\r\n" +
                "    { \"kind\": \"NO\", \"symbol\": \"Start_PB_启动按钮\" },\r\n" +
                "    { \"kind\": \"NC\", \"symbol\": \"Stop_OK_停止正常\" }\r\n" +
                "  ],\r\n" +
                "  \"actions\": [\r\n" +
                "    { \"kind\": \"COIL\", \"symbol\": \"Motor_Run_电机运行\" }\r\n" +
                "  ]\r\n" +
                "}";
        }

        private void AddLadConditionFromFields()
        {
            string kind = SelectedText(ladConditionKindBox, "NO").Trim().ToUpperInvariant();
            string left = ladConditionLeftBox.Text.Trim();
            string right = ladConditionRightBox.Text.Trim();
            string sourceType = ladConditionSourceTypeBox.Text.Trim();
            if (string.IsNullOrWhiteSpace(left))
            {
                MessageBox.Show("请填写符号或左操作数。", "添加LAD条件", MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }
            if ((kind == "P_EDGE" || kind == "N_EDGE") && string.IsNullOrWhiteSpace(right))
            {
                MessageBox.Show("P_EDGE/N_EDGE 需要填写边沿记忆位。", "添加LAD条件", MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }
            if (kind == "EQ" || kind == "NE" || kind == "GE" || kind == "GT" || kind == "LE" || kind == "LT")
            {
                if (string.IsNullOrWhiteSpace(right))
                {
                    MessageBox.Show("比较条件需要填写右操作数。", "添加LAD条件", MessageBoxButtons.OK, MessageBoxIcon.Information);
                    return;
                }
                if (string.IsNullOrWhiteSpace(sourceType)) { sourceType = "Int"; }
            }

            ladConditionList.Items.Add(new LadConditionEntry
            {
                Kind = kind,
                Left = left,
                Right = right,
                SourceType = sourceType
            });
            ladConditionLeftBox.Clear();
            ladConditionRightBox.Clear();
            SyncLadSpecFromEditor();
        }

        private void RemoveSelectedLadCondition()
        {
            if (ladConditionList.SelectedIndex >= 0)
            {
                ladConditionList.Items.RemoveAt(ladConditionList.SelectedIndex);
                SyncLadSpecFromEditor();
            }
        }

        private void AddLadActionFromFields()
        {
            string kind = SelectedText(ladActionKindBox, "COIL").Trim().ToUpperInvariant();
            string target = ladActionTargetBox.Text.Trim();
            string instance = ladActionInstanceBox.Text.Trim();
            string pt = ladActionPtBox.Text.Trim();
            if ((kind == "COIL" || kind == "SET" || kind == "RESET") && string.IsNullOrWhiteSpace(target))
            {
                MessageBox.Show("线圈、置位和复位动作需要填写目标符号。", "添加LAD动作", MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }
            if ((kind == "TON" || kind == "TOF" || kind == "TP") &&
                (string.IsNullOrWhiteSpace(instance) || string.IsNullOrWhiteSpace(pt)))
            {
                MessageBox.Show("定时器动作需要填写实例和PT，例如 IEC_Timer_0_DB_1、T#1s。", "添加LAD动作", MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }
            if ((kind == "CTU" || kind == "CTD" || kind == "CTUD") && string.IsNullOrWhiteSpace(instance))
            {
                MessageBox.Show("计数器动作需要填写实例。目标栏可填写PV符号，留空时默认为1。", "添加LAD动作", MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }
            if (kind == "MOVE" && (string.IsNullOrWhiteSpace(target) || (string.IsNullOrWhiteSpace(instance) && target.IndexOf("->", StringComparison.Ordinal) < 0)))
            {
                MessageBox.Show("MOVE 请在目标栏填写 源 -> 目标，或目标栏填目标、实例栏填源。", "添加LAD动作", MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }
            if (kind == "CALL" && string.IsNullOrWhiteSpace(target))
            {
                MessageBox.Show("CALL 动作需要在目标栏填写块名，例如 MC_Power。", "添加LAD动作", MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }

            ladActionList.Items.Add(new LadActionEntry
            {
                Kind = kind,
                Target = target,
                Instance = instance,
                Pt = pt
            });
            ladActionTargetBox.Clear();
            ladActionInstanceBox.Clear();
            ladActionPtBox.Clear();
            SyncLadSpecFromEditor();
        }

        private void RemoveSelectedLadAction()
        {
            if (ladActionList.SelectedIndex >= 0)
            {
                ladActionList.Items.RemoveAt(ladActionList.SelectedIndex);
                SyncLadSpecFromEditor();
            }
        }

        private void SyncLadSpecFromEditor()
        {
            ladSpecBox.Text = BuildLadSpecJsonFromEditor();
            ladEditorStatusLabel.Text = "结构化输入已同步到 JSON；可继续直接编辑右侧规格，再点击“JSON读入结构”检查可视化条目。";
        }

        private string BuildLadSpecJsonFromEditor()
        {
            StringBuilder builder = new StringBuilder();
            builder.AppendLine("{");
            builder.AppendLine("  \"title\": " + JsonString(ladTitleBox.Text.Trim()) + ",");
            builder.AppendLine("  \"comment\": " + JsonString(ladCommentBox.Text.Trim()) + ",");
            builder.AppendLine("  \"conditions\": [");
            for (int i = 0; i < ladConditionList.Items.Count; i++)
            {
                LadConditionEntry entry = ladConditionList.Items[i] as LadConditionEntry;
                if (entry == null) { continue; }
                builder.Append("    { \"kind\": " + JsonString(entry.Kind));
                if (entry.Kind == "NO" || entry.Kind == "NC")
                {
                    builder.Append(", \"symbol\": " + JsonString(entry.Left));
                }
                else if (entry.Kind == "P_EDGE" || entry.Kind == "N_EDGE")
                {
                    builder.Append(", \"symbol\": " + JsonString(entry.Left));
                    builder.Append(", \"bitSymbol\": " + JsonString(entry.Right));
                }
                else
                {
                    builder.Append(", \"sourceType\": " + JsonString(string.IsNullOrWhiteSpace(entry.SourceType) ? "Int" : entry.SourceType));
                    builder.Append(", \"left\": " + BuildLadOperandJson(entry.Left, entry.SourceType));
                    builder.Append(", \"right\": " + BuildLadOperandJson(entry.Right, entry.SourceType));
                }
                builder.Append(" }");
                if (i < ladConditionList.Items.Count - 1) { builder.Append(","); }
                builder.AppendLine();
            }
            builder.AppendLine("  ],");
            builder.AppendLine("  \"actions\": [");
            for (int i = 0; i < ladActionList.Items.Count; i++)
            {
                LadActionEntry entry = ladActionList.Items[i] as LadActionEntry;
                if (entry == null) { continue; }
                builder.Append("    { \"kind\": " + JsonString(entry.Kind));
                if (entry.Kind == "COIL" || entry.Kind == "SET" || entry.Kind == "RESET")
                {
                    builder.Append(", \"symbol\": " + JsonString(entry.Target));
                }
                else if (entry.Kind == "TON" || entry.Kind == "TOF" || entry.Kind == "TP")
                {
                    builder.Append(", \"instance\": " + JsonString(entry.Instance));
                    builder.Append(", \"pt\": " + JsonString(entry.Pt));
                }
                else if (entry.Kind == "MOVE")
                {
                    string source = entry.Instance;
                    string target = entry.Target;
                    int arrow = target.IndexOf("->", StringComparison.Ordinal);
                    if (arrow >= 0)
                    {
                        source = target.Substring(0, arrow).Trim();
                        target = target.Substring(arrow + 2).Trim();
                    }
                    builder.Append(", \"source\": " + BuildLadOperandJson(source, ""));
                    builder.Append(", \"target\": { \"symbol\": " + JsonString(target) + " }");
                }
                else if (entry.Kind == "CTU" || entry.Kind == "CTD" || entry.Kind == "CTUD")
                {
                    builder.Append(", \"instance\": " + JsonString(entry.Instance));
                    builder.Append(", \"valueType\": \"Int\"");
                    builder.Append(", \"pv\": " + BuildLadOperandJson(string.IsNullOrWhiteSpace(entry.Target) ? "1" : entry.Target, "Int"));
                }
                else if (entry.Kind == "CALL")
                {
                    builder.Append(", \"partName\": " + JsonString(entry.Target));
                    if (!string.IsNullOrWhiteSpace(entry.Instance))
                    {
                        builder.Append(", \"instance\": " + JsonString(entry.Instance));
                    }
                    builder.Append(", \"powerRail\": true");
                }
                builder.Append(" }");
                if (i < ladActionList.Items.Count - 1) { builder.Append(","); }
                builder.AppendLine();
            }
            builder.AppendLine("  ]");
            builder.Append("}");
            return builder.ToString();
        }

        private static string BuildLadOperandJson(string value, string constantType)
        {
            string text = (value ?? "").Trim();
            if (Regex.IsMatch(text, "^(T#|L#|D#|-?\\d+(\\.\\d+)?$|TRUE$|FALSE$)", RegexOptions.IgnoreCase))
            {
                return "{ \"value\": " + JsonString(text) + ", \"constantType\": " + JsonString(string.IsNullOrWhiteSpace(constantType) ? "Int" : constantType) + " }";
            }
            return "{ \"symbol\": " + JsonString(text) + " }";
        }

        private void SaveLadSpecToDisk()
        {
            try
            {
                string root = ResolveProjectRoot(projectPathBox.Text);
                string directory = Path.Combine(root, "PLC_Code", "lad-editor");
                Directory.CreateDirectory(directory);
                if (string.IsNullOrWhiteSpace(currentLadSpecPath))
                {
                    currentLadSpecPath = Path.Combine(directory, "latest-network.json");
                }
                BackupLadArtifact(currentLadSpecPath);
                File.WriteAllText(currentLadSpecPath, ladSpecBox.Text, Encoding.UTF8);
                ladEditorStatusLabel.Text = "JSON规格已保存：" + currentLadSpecPath;
                jobBox.AppendText(Environment.NewLine + "LAD JSON已保存：" + currentLadSpecPath + Environment.NewLine);
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "保存LAD JSON失败", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private void LoadLadEditorFromSpec()
        {
            try
            {
                if (string.IsNullOrWhiteSpace(currentLadSpecPath) && !string.IsNullOrWhiteSpace(projectRoot))
                {
                    currentLadSpecPath = Path.Combine(projectRoot, "PLC_Code", "lad-editor", "latest-network.json");
                }
                string json = !string.IsNullOrWhiteSpace(currentLadSpecPath) && File.Exists(currentLadSpecPath)
                    ? ReadText(currentLadSpecPath)
                    : ladSpecBox.Text;
                if (string.IsNullOrWhiteSpace(json)) { json = DefaultLadSpecJson(); }

                ladTitleBox.Text = JsonStringValue(json, "title", "LAD network");
                ladCommentBox.Text = JsonStringValue(json, "comment", "");
                ladConditionList.Items.Clear();
                ladActionList.Items.Clear();

                foreach (string item in ExtractJsonObjects(ExtractJsonArray(json, "conditions")))
                {
                    string kind = JsonStringValue(item, "kind", "NO").ToUpperInvariant();
                    string left = JsonStringValue(item, "symbol", "");
                    string right = JsonStringValue(item, "bitSymbol", "");
                    string sourceType = JsonStringValue(item, "sourceType", "");
                    string leftObject = ExtractJsonObject(item, "left");
                    string rightObject = ExtractJsonObject(item, "right");
                    if (string.IsNullOrWhiteSpace(left) && !string.IsNullOrWhiteSpace(leftObject))
                    {
                        left = JsonStringValue(leftObject, "symbol", JsonStringValue(leftObject, "value", ""));
                    }
                    if (string.IsNullOrWhiteSpace(right) && !string.IsNullOrWhiteSpace(rightObject))
                    {
                        right = JsonStringValue(rightObject, "symbol", JsonStringValue(rightObject, "value", ""));
                    }
                    ladConditionList.Items.Add(new LadConditionEntry
                    {
                        Kind = kind,
                        Left = left,
                        Right = right,
                        SourceType = sourceType
                    });
                }

                foreach (string item in ExtractJsonObjects(ExtractJsonArray(json, "actions")))
                {
                    string kind = JsonStringValue(item, "kind", "COIL").ToUpperInvariant();
                    string target = JsonStringValue(item, "symbol", "");
                    string instance = JsonStringValue(item, "instance", "");
                    string pt = JsonStringValue(item, "pt", "");
                    if (kind == "MOVE")
                    {
                        string sourceObject = ExtractJsonObject(item, "source");
                        string targetObject = ExtractJsonObject(item, "target");
                        string source = JsonStringValue(sourceObject, "symbol", JsonStringValue(sourceObject, "value", ""));
                        target = JsonStringValue(targetObject, "symbol", target);
                        target = source + " -> " + target;
                    }
                    else if (kind == "CALL")
                    {
                        target = JsonStringValue(item, "partName", target);
                    }
                    else if (kind == "CTU" || kind == "CTD" || kind == "CTUD")
                    {
                        string pvObject = ExtractJsonObject(item, "pv");
                        target = JsonStringValue(pvObject, "symbol", JsonStringValue(pvObject, "value", ""));
                    }
                    ladActionList.Items.Add(new LadActionEntry
                    {
                        Kind = kind,
                        Target = target,
                        Instance = instance,
                        Pt = pt
                    });
                }

                ladSpecBox.Text = json;
                ladEditorStatusLabel.Text = "已从JSON读入结构；右侧仍可直接编辑完整规格。";
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "读取LAD JSON失败", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }

        private static string ExtractJsonArray(string json, string propertyName)
        {
            string source = json ?? "";
            Match match = Regex.Match(source, "\\\"" + Regex.Escape(propertyName) + "\\\"\\s*:\\s*\\[", RegexOptions.Singleline);
            if (!match.Success) { return ""; }
            int start = source.IndexOf('[', match.Index);
            int end = FindJsonClosingToken(source, start, '[', ']');
            return end > start ? source.Substring(start + 1, end - start - 1) : "";
        }

        private static string ExtractJsonObject(string json, string propertyName)
        {
            string source = json ?? "";
            Match match = Regex.Match(source, "\\\"" + Regex.Escape(propertyName) + "\\\"\\s*:\\s*\\{", RegexOptions.Singleline);
            if (!match.Success) { return ""; }
            int start = source.IndexOf('{', match.Index);
            int end = FindJsonClosingToken(source, start, '{', '}');
            return end > start ? source.Substring(start, end - start + 1) : "";
        }

        private static IEnumerable<string> ExtractJsonObjects(string arrayBody)
        {
            if (string.IsNullOrWhiteSpace(arrayBody)) { yield break; }
            int depth = 0;
            int start = -1;
            bool quoted = false;
            bool escaped = false;
            for (int i = 0; i < arrayBody.Length; i++)
            {
                char c = arrayBody[i];
                if (quoted)
                {
                    if (escaped) { escaped = false; }
                    else if (c == '\\') { escaped = true; }
                    else if (c == '"') { quoted = false; }
                    continue;
                }
                if (c == '"') { quoted = true; continue; }
                if (c == '{')
                {
                    if (depth == 0) { start = i; }
                    depth++;
                }
                else if (c == '}')
                {
                    depth--;
                    if (depth == 0 && start >= 0)
                    {
                        yield return arrayBody.Substring(start, i - start + 1);
                        start = -1;
                    }
                }
            }
        }

        private static int FindJsonClosingToken(string text, int start, char open, char close)
        {
            if (start < 0 || start >= text.Length) { return -1; }
            int depth = 0;
            bool quoted = false;
            bool escaped = false;
            for (int i = start; i < text.Length; i++)
            {
                char c = text[i];
                if (quoted)
                {
                    if (escaped) { escaped = false; }
                    else if (c == '\\') { escaped = true; }
                    else if (c == '"') { quoted = false; }
                    continue;
                }
                if (c == '"') { quoted = true; continue; }
                if (c == open) { depth++; }
                else if (c == close)
                {
                    depth--;
                    if (depth == 0) { return i; }
                }
            }
            return -1;
        }

        private void LoadLadNetworkFromXml()
        {
            try
            {
                if (string.IsNullOrWhiteSpace(inputXmlBox.Text) || !File.Exists(inputXmlBox.Text))
                {
                    throw new FileNotFoundException("请先在项目树选择导出的 LAD XML。", inputXmlBox.Text);
                }
                int index;
                if (!int.TryParse(ladNetworkIndexBox.Text.Trim(), out index) || index < 1)
                {
                    throw new InvalidOperationException("网络编号必须是大于0的整数。");
                }

                XmlDocument document = new XmlDocument();
                document.PreserveWhitespace = true;
                document.Load(inputXmlBox.Text);
                XmlNodeList units = document.SelectNodes("//*[local-name()='CompileUnit' or local-name()='SW.Blocks.CompileUnit']");
                if (units == null || index > units.Count)
                {
                    throw new InvalidOperationException("XML中没有找到第 " + index.ToString() + " 个网络。");
                }

                XmlNode unit = units[index - 1];
                ladTitleBox.Text = LadXmlText(unit, "Title", ladTitleBox.Text);
                ladCommentBox.Text = LadXmlText(unit, "Comment", ladCommentBox.Text);
                Dictionary<string, string> accessMap = LadAccessMap(unit);
                Dictionary<string, Dictionary<string, string>> connectionMap = LadConnectionMap(unit, accessMap);
                ladConditionList.Items.Clear();
                ladActionList.Items.Clear();

                XmlNodeList parts = unit.SelectNodes(".//*[local-name()='FlgNet']/*[local-name()='Parts']/*[local-name()='Part']");
                if (parts != null)
                {
                    foreach (XmlNode part in parts)
                    {
                        string name = part.Attributes["Name"] == null ? "" : part.Attributes["Name"].Value;
                        string uid = part.Attributes["UId"] == null ? "" : part.Attributes["UId"].Value;
                        string first = LadConnection(connectionMap, uid, "operand");
                        if (name == "Contact" || name == "PContact" || name == "NContact")
                        {
                            ladConditionList.Items.Add(new LadConditionEntry
                            {
                                Kind = name == "Contact" ? (part.SelectSingleNode("./*[local-name()='Negated' and @Name='operand']") == null ? "NO" : "NC") : (name == "PContact" ? "P_EDGE" : "N_EDGE"),
                                Left = first,
                                Right = name == "Contact" ? "" : LadConnection(connectionMap, uid, "bit"),
                                SourceType = ""
                            });
                        }
                        else if (name == "Eq" || name == "Ne" || name == "Ge" || name == "Gt" || name == "Le" || name == "Lt")
                        {
                            ladConditionList.Items.Add(new LadConditionEntry
                            {
                                Kind = name.ToUpperInvariant(),
                                Left = LadConnection(connectionMap, uid, "in1"),
                                Right = LadConnection(connectionMap, uid, "in2"),
                                SourceType = LadTemplateValue(part, "SrcType", "Int")
                            });
                        }
                        else if (IsLadActionPart(name))
                        {
                            string actionKind = LadActionKind(name);
                            string target = first;
                            string instance = LadInstanceName(part);
                            string pt = LadConnection(connectionMap, uid, "PT");
                            if (actionKind == "MOVE")
                            {
                                target = LadConnection(connectionMap, uid, "in") + " -> " + LadConnection(connectionMap, uid, "out1");
                            }
                            else if (actionKind == "CALL")
                            {
                                target = name;
                            }
                            ladActionList.Items.Add(new LadActionEntry
                            {
                                Kind = actionKind,
                                Target = target,
                                Instance = instance,
                                Pt = pt
                            });
                        }
                    }
                }

                SyncLadSpecFromEditor();
                ladEditorStatusLabel.Text = "已从 XML 读取网络 " + index.ToString() + " 的可编辑摘要；复杂分支和CALL参数请在右侧JSON中补全。";
                SelectMainTab(11);
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "读取LAD网络失败", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }

        private void GenerateLadXml()
        {
            try
            {
                string root = ResolveProjectRoot(projectPathBox.Text);
                if (string.IsNullOrWhiteSpace(inputXmlBox.Text) || !File.Exists(inputXmlBox.Text))
                {
                    throw new FileNotFoundException("请先选择目标 LAD XML，生成器会在其基础上替换指定网络。", inputXmlBox.Text);
                }
                int index;
                if (!int.TryParse(ladNetworkIndexBox.Text.Trim(), out index) || index < 1)
                {
                    throw new InvalidOperationException("网络编号必须是大于0的整数。");
                }
                string directory = Path.Combine(root, "PLC_Code", "lad-editor");
                Directory.CreateDirectory(directory);
                if (string.IsNullOrWhiteSpace(currentLadSpecPath))
                {
                    currentLadSpecPath = Path.Combine(directory, "latest-network.json");
                }
                BackupLadArtifact(currentLadSpecPath);
                File.WriteAllText(currentLadSpecPath, ladSpecBox.Text, Encoding.UTF8);
                currentLadGeneratedXmlPath = Path.Combine(directory, "latest.generated.xml");
                BackupLadArtifact(currentLadGeneratedXmlPath);
                StartCommand("write-lad-network");
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "生成LAD XML失败", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private void VerifyLadEditorOutput()
        {
            string candidate = currentLadGeneratedXmlPath;
            if (string.IsNullOrWhiteSpace(candidate) || !File.Exists(candidate))
            {
                MessageBox.Show("请先点击“生成XML”，再进行克隆编译验证。", "LAD克隆验证", MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }
            inputXmlBox.Text = candidate;
            StartCommand("write-cycle");
        }

        private void BackupLadArtifact(string path)
        {
            if (string.IsNullOrWhiteSpace(path) || !File.Exists(path)) { return; }
            string root = ResolveProjectRoot(projectPathBox.Text);
            string backupDirectory = Path.Combine(root, "PLC_Code", "lad-editor", "backups", DateTime.Now.ToString("yyyyMMdd-HHmmssfff"));
            Directory.CreateDirectory(backupDirectory);
            File.Copy(path, Path.Combine(backupDirectory, Path.GetFileName(path)), false);
        }

        private static bool IsLadActionPart(string name)
        {
            return name == "Coil" || name == "SCoil" || name == "RCoil" ||
                name == "TON" || name == "TOF" || name == "TP" || name == "Move" ||
                name == "CTU" || name == "CTD" || name == "CTUD";
        }

        private static string LadActionKind(string name)
        {
            if (name == "Coil") { return "COIL"; }
            if (name == "SCoil") { return "SET"; }
            if (name == "RCoil") { return "RESET"; }
            return name.ToUpperInvariant();
        }

        private static string LadXmlText(XmlNode unit, string compositionName, string fallback)
        {
            XmlNode node = unit.SelectSingleNode("./*[local-name()='ObjectList']/*[local-name()='MultilingualText' and @CompositionName='" + compositionName + "']//*[local-name()='Text']");
            return node == null ? fallback : node.InnerText;
        }

        private static string LadTemplateValue(XmlNode node, string name, string fallback)
        {
            XmlNode value = node.SelectSingleNode("./*[local-name()='TemplateValue' and @Name='" + name + "']");
            return value == null || string.IsNullOrWhiteSpace(value.InnerText) ? fallback : value.InnerText;
        }

        private static Dictionary<string, string> LadAccessMap(XmlNode unit)
        {
            Dictionary<string, string> result = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            XmlNodeList accesses = unit.SelectNodes(".//*[local-name()='Access']");
            if (accesses == null) { return result; }
            foreach (XmlNode access in accesses)
            {
                XmlAttribute uid = access.Attributes["UId"];
                if (uid == null) { continue; }
                List<string> components = new List<string>();
                foreach (XmlNode component in access.SelectNodes("./*[local-name()='Symbol']/*[local-name()='Component']"))
                {
                    XmlAttribute name = component.Attributes["Name"];
                    if (name != null) { components.Add(name.Value); }
                }
                string value = string.Join(".", components.ToArray());
                if (string.IsNullOrWhiteSpace(value))
                {
                    XmlNode constant = access.SelectSingleNode(".//*[local-name()='ConstantValue']");
                    value = constant == null ? "" : constant.InnerText;
                }
                result[uid.Value] = value;
            }
            return result;
        }

        private static Dictionary<string, Dictionary<string, string>> LadConnectionMap(XmlNode unit, Dictionary<string, string> accessMap)
        {
            Dictionary<string, Dictionary<string, string>> result = new Dictionary<string, Dictionary<string, string>>(StringComparer.OrdinalIgnoreCase);
            XmlNodeList wires = unit.SelectNodes(".//*[local-name()='FlgNet']/*[local-name()='Wires']/*[local-name()='Wire']");
            if (wires == null) { return result; }
            foreach (XmlNode wire in wires)
            {
                string accessUid = "";
                XmlNode ident = wire.SelectSingleNode("./*[local-name()='IdentCon']");
                if (ident != null && ident.Attributes["UId"] != null) { accessUid = ident.Attributes["UId"].Value; }
                if (string.IsNullOrWhiteSpace(accessUid) || !accessMap.ContainsKey(accessUid)) { continue; }
                XmlNodeList names = wire.SelectNodes("./*[local-name()='NameCon']");
                if (names == null) { continue; }
                foreach (XmlNode nameCon in names)
                {
                    if (nameCon.Attributes["UId"] == null || nameCon.Attributes["Name"] == null) { continue; }
                    string partUid = nameCon.Attributes["UId"].Value;
                    if (!result.ContainsKey(partUid)) { result[partUid] = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase); }
                    string port = nameCon.Attributes["Name"].Value;
                    if (!result[partUid].ContainsKey(port) || string.IsNullOrWhiteSpace(result[partUid][port]))
                    {
                        result[partUid][port] = accessMap[accessUid];
                    }
                }
            }
            return result;
        }

        private static string LadConnection(Dictionary<string, Dictionary<string, string>> map, string partUid, string port)
        {
            Dictionary<string, string> ports;
            string value;
            return map.TryGetValue(partUid, out ports) && ports.TryGetValue(port, out value) ? value : "";
        }

        private static string LadInstanceName(XmlNode part)
        {
            List<string> components = new List<string>();
            foreach (XmlNode component in part.SelectNodes("./*[local-name()='Instance']/*[local-name()='Component']"))
            {
                XmlAttribute name = component.Attributes["Name"];
                if (name != null) { components.Add(name.Value); }
            }
            return string.Join(".", components.ToArray());
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
                        currentPreviewPath = "";
                        previewBox.Text = DirectoryListing(info.Path);
                    }
                }
            };

            fontSizeBox.SelectedIndexChanged += delegate { ApplySelectedFont(); SaveWorkflowConfig(false); };
            fontBox.SelectedIndexChanged += delegate { ApplySelectedFont(); SaveWorkflowConfig(false); };
            modelBox.SelectedIndexChanged += delegate
            {
                if (synchronizingSettings) { return; }
                SyncQuickSettingsFromAdvanced();
                SaveWorkflowConfig(false);
            };
            modelBox.Leave += delegate { SyncQuickSettingsFromAdvanced(); SaveWorkflowConfig(false); };
            workflowSelectBox.SelectedIndexChanged += delegate
            {
                if (synchronizingSettings) { return; }
                if (!loadingWorkflowConfig && !applyingWorkflowDefaults)
                {
                    workflowAutoMode = SelectedText(workflowSelectBox, "自动选择") == "自动选择";
                }
                if (!loadingWorkflowConfig)
                {
                    ApplyWorkflowDefaults(false);
                }
                SyncQuickSettingsFromAdvanced();
                SaveWorkflowConfig(false);
            };
            quickModelBox.SelectedIndexChanged += delegate { ApplyQuickSettingsToAdvanced(false); };
            quickModelBox.Leave += delegate { ApplyQuickSettingsToAdvanced(false); };
            quickWorkflowBox.SelectedIndexChanged += delegate { ApplyQuickSettingsToAdvanced(true); };
            quickRoutingModeBox.SelectedIndexChanged += delegate { ApplyQuickSettingsToAdvanced(false); };
            quickPlatformBox.SelectedIndexChanged += delegate { ApplyQuickSettingsToAdvanced(false); };
            routingModeBox.SelectedIndexChanged += delegate
            {
                if (synchronizingSettings) { return; }
                if (SelectedRoutingMode() == "manual" && SelectedPlatformId() == "auto") { SelectPlatformById("codex"); }
                ResetAgentSessionForRoutingChange("路由模式已切换");
                SyncQuickSettingsFromAdvanced();
                SaveWorkflowConfig(false);
            };
            platformBox.SelectedIndexChanged += delegate
            {
                if (synchronizingSettings) { return; }
                ResetAgentSessionForRoutingChange("AI平台已切换");
                SyncQuickSettingsFromAdvanced();
                SaveWorkflowConfig(false);
            };
            agentBox.SelectedIndexChanged += delegate
            {
                if (!loadingWorkflowConfig && !applyingWorkflowDefaults && (!string.IsNullOrWhiteSpace(agentThreadId) || !string.IsNullOrWhiteSpace(agentSessionPlatform)))
                {
                    agentThreadId = "";
                    agentSessionPlatform = "";
                    activePlatformName = "";
                    activePlatformModel = "";
                    chatBox.AppendText(Environment.NewLine + "--- Agent 已切换，自动开始新会话 ---" + Environment.NewLine);
                }
                SaveWorkflowConfig(false);
            };
            agentSandboxBox.SelectedIndexChanged += delegate { SaveWorkflowConfig(false); };
            agentSearchBox.CheckedChanged += delegate { SaveWorkflowConfig(false); };
            languagePreferenceBox.SelectedIndexChanged += delegate { SaveWorkflowConfig(false); };
            tiaSessionModeBox.SelectedIndexChanged += delegate { SaveWorkflowConfig(false); };
            safetyModeBox.SelectedIndexChanged += delegate { SaveWorkflowConfig(false); };
            timeoutSecondsBox.SelectedIndexChanged += delegate { SaveWorkflowConfig(false); };
            apiProviderBox.SelectedIndexChanged += delegate { SaveWorkflowConfig(false); };
            imageWorkflowBox.SelectedIndexChanged += delegate { SaveWorkflowConfig(false); };
            imageModelBox.SelectedIndexChanged += delegate { SaveWorkflowConfig(false); };
            imageQualityBox.SelectedIndexChanged += delegate { SaveWorkflowConfig(false); };
            imageSizeBox.SelectedIndexChanged += delegate { SaveWorkflowConfig(false); };
            componentStrategyBox.SelectedIndexChanged += delegate { SaveWorkflowConfig(false); };
            winccFlavorBox.SelectedIndexChanged += delegate { SaveWorkflowConfig(false); };
            winccPluginPolicyBox.SelectedIndexChanged += delegate { SaveWorkflowConfig(false); };
            apiBaseBox.Leave += delegate { SaveWorkflowConfig(false); };
            apiKeyEnvBox.Leave += delegate { SaveWorkflowConfig(false); };
            codexCommandBox.Leave += delegate { SaveWorkflowConfig(false); };
            claudeCommandBox.Leave += delegate { SaveWorkflowConfig(false); };
            traeCommandBox.Leave += delegate { SaveWorkflowConfig(false); };
            qoderCommandBox.Leave += delegate { SaveWorkflowConfig(false); };
            traeProviderBox.Leave += delegate { SaveWorkflowConfig(false); };
            winccGraphqlUrlBox.Leave += delegate { SaveWorkflowConfig(false); };
            tiaMcpPathBox.Leave += delegate { SaveWorkflowConfig(false); };
            showScriptsPathBox.Leave += delegate { SaveWorkflowConfig(false); };
            runtimeMcpPathBox.Leave += delegate { SaveWorkflowConfig(false); };
            plcNameBox.Leave += delegate { SaveWorkflowConfig(false); };
            requestBox.TextChanged += delegate { ApplyWorkflowDefaults(true); };
            requestBox.KeyDown += delegate (object sender, KeyEventArgs eventArgs)
            {
                if (eventArgs.Control && eventArgs.KeyCode == Keys.Enter)
                {
                    eventArgs.SuppressKeyPress = true;
                    SendAgentMessage();
                }
            };
            referenceImageBox.TextChanged += delegate
            {
                if (File.Exists(referenceImageBox.Text))
                {
                    LoadReferencePreview(referenceImageBox.Text);
                }
                SaveWorkflowConfig(false);
            };
            FormClosing += delegate
            {
                SaveWorkflowConfig(false);
                if (agentProcess != null && !agentProcess.HasExited)
                {
                    StopAgent();
                }
            };
        }

        private void LayoutScrollableContent()
        {
            int width = Math.Max(1100, scrollHost.ClientSize.Width - SystemInformation.VerticalScrollBarWidth - 2);
            int height = Math.Max(780, scrollHost.ClientSize.Height + 180);
            scrollContent.Size = new Size(width, height);
            scrollHost.AutoScrollMinSize = new Size(width, height);
        }

        private void ScrollHostByWheel(MouseEventArgs e)
        {
            int current = -scrollHost.AutoScrollPosition.Y;
            int next = Math.Max(0, current - e.Delta);
            scrollHost.AutoScrollPosition = new Point(0, next);
        }

        private static void LayoutHeader(Panel top, Label title, TextBox pathBox, Button autoButton, Button browseButton, Button loadButton, Label badge, Label status)
        {
            int w = Math.Max(980, top.ClientSize.Width);
            title.Location = new Point(18, 21);
            title.AutoSize = true;

            int badgeWidth = 82;
            int buttonGap = 10;
            int right = w - 18;
            badge.Size = new Size(badgeWidth, 28);
            badge.Location = new Point(right - badgeWidth, 19);

            int loadWidth = 96;
            int browseWidth = 104;
            int autoWidth = 118;
            loadButton.Size = new Size(loadWidth, 38);
            browseButton.Size = new Size(browseWidth, 38);
            autoButton.Size = new Size(autoWidth, 38);

            int x = badge.Left - buttonGap - loadWidth;
            loadButton.Location = new Point(x, 14);
            x -= buttonGap + browseWidth;
            browseButton.Location = new Point(x, 14);
            x -= buttonGap + autoWidth;
            autoButton.Location = new Point(x, 14);

            int pathLeft = Math.Max(142, title.Right + 28);
            int pathRight = Math.Max(pathLeft + 220, autoButton.Left - 18);
            pathBox.Location = new Point(pathLeft, 18);
            pathBox.Size = new Size(pathRight - pathLeft, 28);

            int statusWidth = Math.Max(160, autoButton.Left - pathLeft - 18);
            status.Location = new Point(pathLeft, 50);
            status.Size = new Size(statusWidth, 18);
        }

        private void ConfigureSettingsControls()
        {
            string[] models = new string[] { "继承平台/工作流默认", "gpt-5.5", "gpt-5.4", "gpt-5.4-mini", "gpt-5.2", "sonnet", "opus", "自定义模型ID" };
            string[] workflows = new string[] { "自动选择", "工作台自动开发", "Agent执行队列", "读取项目并总结", "LAD编写与验证", "PLC高级指令与工艺对象", "SCL编写与验证", "DB+程序块协同", "WinCC画面生成", "WinCC参考图复刻", "Openness自动化", "安全风险评估", "故障诊断", "工业化重构", "只读审查" };
            ConfigureCombo(routingModeBox, new string[] { "自动路由", "手动指定" }, "自动路由", 118);
            ConfigureCombo(platformBox, new string[] { "自动选择", "Codex", "Claude Code", "Trae Agent", "Qoder" }, "自动选择", 132);
            ConfigureCombo(quickRoutingModeBox, new string[] { "自动路由", "手动指定" }, "自动路由", 108);
            ConfigureCombo(quickPlatformBox, new string[] { "自动选择", "Codex", "Claude Code", "Trae Agent", "Qoder" }, "自动选择", 120);
            ConfigureCombo(agentBox, new string[] { "自动路由 Agent", "工作台编排 Agent", "队列执行 Agent", "PLC LAD 工程师", "PLC SCL 工程师", "PLC 高级指令工程师", "DB 与变量架构师", "WinCC 画面工程师", "Openness 自动化工程师", "编译诊断 Agent", "只读审查 Agent" }, "自动路由 Agent", 166);
            ConfigureCombo(agentSandboxBox, new string[] { "只读", "工作区读写", "完全访问" }, "工作区读写", 142);
            agentSearchBox.Text = "允许联网检索";
            agentSearchBox.Checked = true;
            agentSearchBox.AutoSize = true;
            agentSearchBox.ForeColor = Ink;
            agentSearchBox.Font = new Font("Microsoft YaHei UI", 9F);
            ConfigureCombo(modelBox, models, "继承平台/工作流默认", 168);
            ConfigureCombo(workflowSelectBox, workflows, "自动选择", 168);
            ConfigureCombo(quickModelBox, models, "继承平台/工作流默认", 152);
            ConfigureCombo(quickWorkflowBox, workflows, "自动选择", 154);
            modelBox.DropDownStyle = ComboBoxStyle.DropDown;
            quickModelBox.DropDownStyle = ComboBoxStyle.DropDown;
            ConfigureCombo(languagePreferenceBox, new string[] { "LAD优先", "按项目现有语言", "FBD优先", "SCL优先" }, "LAD优先", 126);
            ConfigureCombo(tiaSessionModeBox, new string[] { "自动附加", "附加当前TIA", "显示TIA界面" }, "自动附加", 126);
            ConfigureCombo(safetyModeBox, new string[] { "只生成不写入", "克隆编译验证", "克隆验证并生成发布包" }, "克隆编译验证", 168);
            ConfigureCombo(timeoutSecondsBox, new string[] { "300", "600", "900", "1200" }, "600", 72);
            ConfigureCombo(apiProviderBox, new string[] { "Codex内置", "OpenAI API", "Azure OpenAI", "本地/手动" }, "Codex内置", 142);
            ConfigureCombo(imageWorkflowBox, new string[] { "自动", "无图像", "文生图", "图生图/参考图" }, "自动", 142);
            ConfigureCombo(imageModelBox, new string[] { "内置imagegen", "gpt-image-2", "gpt-image-1.5", "自定义" }, "内置imagegen", 142);
            ConfigureCombo(imageQualityBox, new string[] { "auto", "high", "medium", "low" }, "auto", 96);
            ConfigureCombo(imageSizeBox, new string[] { "auto", "1536x1024", "1024x1024", "1920x1080", "3840x2160" }, "1536x1024", 122);
            ConfigureCombo(componentStrategyBox, new string[] { "自动匹配+自定义", "标准WinCC组件", "Faceplate优先", "自定义组件优先", "SiVArc规则生成" }, "自动匹配+自定义", 168);
            ConfigureCombo(winccFlavorBox, new string[] { "自动检测", "WinCC Advanced/Comfort", "WinCC Unified Engineering", "WinCC Unified Runtime", "SiVArc" }, "自动检测", 184);
            ConfigureCombo(winccPluginPolicyBox, new string[] { "自动选择", "仅官方/本机", "允许已审核社区插件", "禁用插件" }, "自动选择", 184);
            PopulateFontOptions();
            fontBox.Width = 178;
            ConfigureCombo(fontSizeBox, new string[] { "9", "10", "11", "12", "14", "16", "18" }, "10", 72);
            apiBaseBox.Width = 260;
            apiBaseBox.Text = "";
            StyleInput(apiBaseBox);
            apiKeyEnvBox.Width = 160;
            apiKeyEnvBox.Text = "OPENAI_API_KEY";
            StyleInput(apiKeyEnvBox);
            ConfigureCommandBox(codexCommandBox, "留空自动检测 Codex");
            ConfigureCommandBox(claudeCommandBox, "留空自动检测 Claude Code");
            ConfigureCommandBox(traeCommandBox, "留空自动检测 Trae Agent");
            ConfigureCommandBox(qoderCommandBox, "留空自动检测 Qoder");
            traeProviderBox.Width = 160;
            StyleInput(traeProviderBox);
            referenceImageBox.Width = 330;
            StyleInput(referenceImageBox);
            winccGraphqlUrlBox.Width = 260;
            StyleInput(winccGraphqlUrlBox);
            tiaMcpPathBox.Width = 260;
            StyleInput(tiaMcpPathBox);
            tiaV20UnifiedMcpPathBox.Width = 260;
            StyleInput(tiaV20UnifiedMcpPathBox);
            tiaOpennessManagerPathBox.Width = 260;
            StyleInput(tiaOpennessManagerPathBox);
            showScriptsPathBox.Width = 260;
            StyleInput(showScriptsPathBox);
            runtimeMcpPathBox.Width = 260;
            StyleInput(runtimeMcpPathBox);
            tiaViewerPathBox.Width = 260;
            StyleInput(tiaViewerPathBox);
        }

        private void BuildMainMenu()
        {
            mainMenu.Dock = DockStyle.Fill;
            mainMenu.AutoSize = false;
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
            view.DropDownItems.Add(NewMenuItem("任务编排", delegate { SelectMainTab(1); }));
            view.DropDownItems.Add(NewMenuItem("日志输出", delegate { SelectMainTab(2); }));
            view.DropDownItems.Add(NewMenuItem("文件预览", delegate { SelectMainTab(3); }));
            view.DropDownItems.Add(NewMenuItem("Runs 列表", delegate { SelectMainTab(4); }));
            view.DropDownItems.Add(NewMenuItem("审查 / Diff", delegate { SelectMainTab(5); }));
            view.DropDownItems.Add(NewMenuItem("验证面板", delegate { SelectMainTab(6); }));
            view.DropDownItems.Add(NewMenuItem("项目模型", delegate { SelectMainTab(7); }));
            view.DropDownItems.Add(NewMenuItem("知识库", delegate { SelectMainTab(8); }));
            view.DropDownItems.Add(NewMenuItem("参考图", delegate { SelectMainTab(9); }));
            view.DropDownItems.Add(NewMenuItem("LAD结构编辑", delegate { SelectMainTab(11); }));
            view.DropDownItems.Add(new ToolStripSeparator());
            view.DropDownItems.Add(NewMenuItem("恢复默认布局", delegate { RestoreDefaultLayout(); }));
            return view;
        }

        private ToolStripMenuItem BuildCodeMenu()
        {
            ToolStripMenuItem code = NewMenu("代码(&C)");
            code.DropDownItems.Add(NewMenuItem("LAD 编写与验证", delegate { SelectCombo(workflowSelectBox, "LAD编写与验证"); ApplyWorkflowDefaults(false); }));
            code.DropDownItems.Add(NewMenuItem("打开 LAD 结构编辑器", delegate { SelectMainTab(11); }));
            code.DropDownItems.Add(NewMenuItem("载入 LAD JSON 模板", delegate { StartCommand("lad-scaffold"); }));
            code.DropDownItems.Add(NewMenuItem("生成 LAD XML", delegate { GenerateLadXml(); }));
            code.DropDownItems.Add(NewMenuItem("克隆验证当前 LAD", delegate { VerifyLadEditorOutput(); }));
            code.DropDownItems.Add(NewMenuItem("生成当前 LAD 预览", delegate { StartCommand("lad-preview"); }));
            code.DropDownItems.Add(NewMenuItem("PLC 高级指令与工艺对象", delegate { SelectCombo(workflowSelectBox, "PLC高级指令与工艺对象"); ApplyWorkflowDefaults(false); }));
            code.DropDownItems.Add(NewMenuItem("生成 PLC 指令/工艺对象方案", delegate { StartCommand("plc-instruction-plan"); }));
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
            run.DropDownItems.Add(NewMenuItem("生成 LAD 可读预览", delegate { StartCommand("lad-preview"); }));
            run.DropDownItems.Add(NewMenuItem("生成项目对象模型", delegate { StartCommand("project-model"); }));
            run.DropDownItems.Add(NewMenuItem("生成任务知识检索包", delegate { StartCommand("knowledge-pack"); }));
            run.DropDownItems.Add(NewMenuItem("生成工作台能力矩阵", delegate { StartCommand("capability-map"); }));
            run.DropDownItems.Add(NewMenuItem("一键生成自动开发流水线", delegate { StartCommand("agent-pipeline"); }));
            run.DropDownItems.Add(NewMenuItem("生成 PLC 改动包", delegate { StartCommand("plc-change-package"); }));
            run.DropDownItems.Add(NewMenuItem("生成 PLC 指令模板库", delegate { StartCommand("plc-instruction-cookbook"); }));
            run.DropDownItems.Add(NewMenuItem("生成 PLC 指令/工艺对象方案", delegate { StartCommand("plc-instruction-plan"); }));
            run.DropDownItems.Add(NewMenuItem("扫描 WinCC 插件", delegate { StartCommand("wincc-plugins"); }));
            run.DropDownItems.Add(NewMenuItem("生成 WinCC 视觉工程包", delegate { StartCommand("wincc-visual-package"); }));
            run.DropDownItems.Add(NewMenuItem("生成 WinCC 组件蓝图", delegate { StartCommand("wincc-component-blueprints"); }));
            run.DropDownItems.Add(NewMenuItem("生成 WinCC 工程脚手架", delegate { StartCommand("wincc-engineering-scaffold"); }));
            run.DropDownItems.Add(NewMenuItem("生成 WinCC Openness 实现包", delegate { StartCommand("wincc-openness-implementation"); }));
            run.DropDownItems.Add(NewMenuItem("读取 WinCC 工程对象", delegate { StartCommand("wincc-read-cycle"); }));
            run.DropDownItems.Add(NewMenuItem("在克隆工程应用 WinCC 包", delegate { StartCommand("wincc-apply-clone"); }));
            run.DropDownItems.Add(NewMenuItem("生成仿真/运行验证包", delegate { StartCommand("simulation-package"); }));
            run.DropDownItems.Add(NewMenuItem("回放仿真场景证据", delegate { StartCommand("simulation-replay"); }));
            run.DropDownItems.Add(NewMenuItem("生成 Agent 任务编排", delegate { StartCommand("agent-plan"); }));
            run.DropDownItems.Add(NewMenuItem("生成 Agent 执行队列", delegate { StartCommand("agent-queue"); }));
            run.DropDownItems.Add(NewMenuItem("队列：开始下一阶段", delegate { StartCommand("queue-start-next"); }));
            run.DropDownItems.Add(NewMenuItem("队列：运行当前阶段", delegate { StartCommand("queue-run-current"); }));
            run.DropDownItems.Add(NewMenuItem("队列：完成当前阶段", delegate { StartCommand("queue-complete-current"); }));
            run.DropDownItems.Add(NewMenuItem("队列：标记当前阶段失败", delegate { StartCommand("queue-fail-current"); }));
            run.DropDownItems.Add(NewMenuItem("生成工作台审查包", delegate { StartCommand("review-package"); }));
            run.DropDownItems.Add(NewMenuItem("刷新工作台总览", delegate { StartCommand("workbench-dashboard"); }));
            run.DropDownItems.Add(NewMenuItem("克隆验证 LAD", delegate { StartCommand("write-cycle"); }));
            return run;
        }

        private ToolStripMenuItem BuildToolsMenu()
        {
            ToolStripMenuItem tools = NewMenu("工具(&T)");
            tools.DropDownItems.Add(BuildSettingsPanelMenu("AI平台 / Agent / 工作流 / WinCC 设置"));
            tools.DropDownItems.Add(new ToolStripSeparator());
            tools.DropDownItems.Add(NewMenuItem("上传 Agent 附件...", delegate { BrowseAgentAttachments(); }));
            tools.DropDownItems.Add(NewMenuItem("发送当前消息", delegate { SendAgentMessage(); }));
            tools.DropDownItems.Add(NewMenuItem("新建 Agent 会话", delegate { NewAgentSession(); }));
            tools.DropDownItems.Add(NewMenuItem("停止 Agent", delegate { StopAgent(); }));
            tools.DropDownItems.Add(new ToolStripSeparator());
            tools.DropDownItems.Add(NewMenuItem("切换文件预览编辑", delegate { editPreviewBox.Checked = !editPreviewBox.Checked; }));
            tools.DropDownItems.Add(NewMenuItem("保存当前预览文件", delegate { SaveCurrentPreviewFile(); }));
            tools.DropDownItems.Add(NewMenuItem("生成项目对象模型", delegate { StartCommand("project-model"); }));
            tools.DropDownItems.Add(NewMenuItem("查看项目对象模型", delegate { ShowProjectObjectModel(); }));
            tools.DropDownItems.Add(NewMenuItem("生成任务知识检索包", delegate { StartCommand("knowledge-pack"); }));
            tools.DropDownItems.Add(NewMenuItem("查看任务知识检索包", delegate { ShowKnowledgePack(); }));
            tools.DropDownItems.Add(NewMenuItem("生成工作台能力矩阵", delegate { StartCommand("capability-map"); }));
            tools.DropDownItems.Add(NewMenuItem("查看工作台能力矩阵", delegate { ShowWorkbenchCapabilityMap(); }));
            tools.DropDownItems.Add(NewMenuItem("一键生成自动开发流水线", delegate { StartCommand("agent-pipeline"); }));
            tools.DropDownItems.Add(NewMenuItem("生成 PLC 改动包", delegate { StartCommand("plc-change-package"); }));
            tools.DropDownItems.Add(NewMenuItem("生成 PLC 指令模板库", delegate { StartCommand("plc-instruction-cookbook"); }));
            tools.DropDownItems.Add(NewMenuItem("查看 PLC 指令模板库", delegate { ShowPlcInstructionCookbook(); }));
            tools.DropDownItems.Add(NewMenuItem("生成 PLC 指令/工艺对象方案", delegate { StartCommand("plc-instruction-plan"); }));
            tools.DropDownItems.Add(new ToolStripSeparator());
            tools.DropDownItems.Add(NewMenuItem("上传 WinCC 参考图...", delegate { BrowseReferenceImage(); }));
            tools.DropDownItems.Add(NewMenuItem("联网扫描 WinCC 插件", delegate { StartCommand("wincc-plugins"); }));
            tools.DropDownItems.Add(NewMenuItem("查看 WinCC 插件路由", delegate { ShowWinccPluginRouting(); }));
            tools.DropDownItems.Add(NewMenuItem("生成 WinCC 视觉工程包", delegate { StartCommand("wincc-visual-package"); }));
            tools.DropDownItems.Add(NewMenuItem("生成 WinCC 组件蓝图", delegate { StartCommand("wincc-component-blueprints"); }));
            tools.DropDownItems.Add(NewMenuItem("查看 WinCC 组件蓝图", delegate { ShowWinccComponentBlueprints(); }));
            tools.DropDownItems.Add(NewMenuItem("生成 WinCC 工程脚手架", delegate { StartCommand("wincc-engineering-scaffold"); }));
            tools.DropDownItems.Add(NewMenuItem("查看 WinCC 工程脚手架", delegate { ShowWinccEngineeringScaffold(); }));
            tools.DropDownItems.Add(NewMenuItem("生成 WinCC Openness 实现包", delegate { StartCommand("wincc-openness-implementation"); }));
            tools.DropDownItems.Add(NewMenuItem("查看 WinCC Openness 实现包", delegate { ShowWinccOpennessImplementation(); }));
            tools.DropDownItems.Add(NewMenuItem("读取 WinCC 工程对象", delegate { StartCommand("wincc-read-cycle"); }));
            tools.DropDownItems.Add(NewMenuItem("在克隆工程应用 WinCC 包", delegate { StartCommand("wincc-apply-clone"); }));
            tools.DropDownItems.Add(NewMenuItem("生成仿真/运行验证包", delegate { StartCommand("simulation-package"); }));
            tools.DropDownItems.Add(NewMenuItem("查看仿真/运行验证包", delegate { ShowSimulationPackage(); }));
            tools.DropDownItems.Add(NewMenuItem("回放仿真场景证据", delegate { StartCommand("simulation-replay"); }));
            tools.DropDownItems.Add(NewMenuItem("查看仿真回放报告", delegate { ShowSimulationReplay(); }));
            tools.DropDownItems.Add(NewMenuItem("生成 Agent 任务编排", delegate { StartCommand("agent-plan"); }));
            tools.DropDownItems.Add(NewMenuItem("生成 Agent 执行队列", delegate { StartCommand("agent-queue"); }));
            tools.DropDownItems.Add(NewMenuItem("查看当前队列阶段", delegate { ShowCurrentQueueStage(); }));
            tools.DropDownItems.Add(NewMenuItem("运行当前队列阶段", delegate { StartCommand("queue-run-current"); }));
            tools.DropDownItems.Add(NewMenuItem("生成工作台审查包", delegate { StartCommand("review-package"); }));
            tools.DropDownItems.Add(NewMenuItem("查看工作台审查包", delegate { ShowWorkbenchReviewPackage(); }));
            tools.DropDownItems.Add(NewMenuItem("刷新工作台总览", delegate { StartCommand("workbench-dashboard"); }));
            tools.DropDownItems.Add(NewMenuItem("查看工作台总览", delegate { ShowWorkbenchDashboard(); }));
            tools.DropDownItems.Add(NewMenuItem("应用字体设置", delegate { ApplySelectedFont(); }));
            tools.DropDownItems.Add(NewMenuItem("按任务自动路由", delegate { ApplyWorkflowDefaults(false); }));
            tools.DropDownItems.Add(NewMenuItem("检测 Codex / Claude / Trae / Qoder", delegate { StartCommand("probe-ai-platforms"); }));
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
            panel.Height = 560;
            panel.AutoScroll = true;
            panel.BackColor = Color.FromArgb(35, 39, 43);

            TableLayoutPanel grid = new TableLayoutPanel();
            grid.Dock = DockStyle.Top;
            grid.AutoSize = true;
            grid.ColumnCount = 4;
            grid.RowCount = 32;
            grid.Padding = new Padding(12);
            grid.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 96));
            grid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50));
            grid.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 96));
            grid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50));
            panel.Controls.Add(grid);

            AddSettingRow(grid, 0, "路由模式", routingModeBox, "执行平台", platformBox);
            AddSettingRow(grid, 1, "Agent 权限", agentSandboxBox, "Agent 联网", agentSearchBox);
            AddSettingRow(grid, 2, "代码模型", modelBox, "工作流", workflowSelectBox);
            AddSettingRow(grid, 3, "Codex 命令", codexCommandBox, "Claude 命令", claudeCommandBox);
            AddSettingRow(grid, 4, "Trae 命令", traeCommandBox, "Qoder 命令", qoderCommandBox);
            AddSettingRow(grid, 5, "Trae Provider", traeProviderBox, "平台检测", NewMenuButton("立即检测", delegate { StartCommand("probe-ai-platforms"); }));
            AddSettingRow(grid, 6, "API 提供方", apiProviderBox, "API Base", apiBaseBox);
            AddSettingRow(grid, 7, "Key 环境变量", apiKeyEnvBox, "图像工作流", imageWorkflowBox);
            AddSettingRow(grid, 8, "图像模型", imageModelBox, "图像质量", imageQualityBox);
            AddSettingRow(grid, 9, "图像尺寸", imageSizeBox, "组件策略", componentStrategyBox);
            AddSettingRow(grid, 10, "WinCC 类型", winccFlavorBox, "插件策略", winccPluginPolicyBox);
            AddSettingRow(grid, 11, "GraphQL URL", winccGraphqlUrlBox, "运行时 MCP", runtimeMcpPathBox);
            AddSettingRow(grid, 12, "TIA MCP", tiaMcpPathBox, "脚本 Add-In", showScriptsPathBox);
            AddSettingRow(grid, 13, "V20 MCP", tiaV20UnifiedMcpPathBox, "OpennessMgr", tiaOpennessManagerPathBox);
            AddSettingRow(grid, 14, "离线预览", tiaViewerPathBox, "界面字体", fontBox);
            AddSettingRow(grid, 15, "字号", fontSizeBox, "参考图", referenceImageBox);
            AddSettingRow(grid, 16, "参考图", NewMenuButton("上传/预览", delegate { BrowseReferenceImage(); }), "配置", NewMenuButton("保存配置", delegate { SaveWorkflowConfig(true); }));
            AddSettingRow(grid, 17, "插件", NewMenuButton("联网扫描", delegate { StartCommand("wincc-plugins"); }), "应用", NewMenuButton("应用字体", delegate { ApplySelectedFont(); }));
            AddSettingRow(grid, 18, "路由", NewMenuButton("按任务推荐", delegate { ApplyWorkflowDefaults(false); }), "会话", NewMenuButton("新建 Agent 会话", delegate { NewAgentSession(); }));
            AddSettingRow(grid, 19, "模型", NewMenuButton("生成上下文", delegate { StartCommand("project-model"); }), "知识", NewMenuButton("生成知识包", delegate { StartCommand("knowledge-pack"); }));
            AddSettingRow(grid, 20, "能力", NewMenuButton("生成矩阵", delegate { StartCommand("capability-map"); }), "预览", NewMenuButton("查看矩阵", delegate { ShowWorkbenchCapabilityMap(); }));
            AddSettingRow(grid, 21, "指令库", NewMenuButton("生成", delegate { StartCommand("plc-instruction-cookbook"); }), "蓝图", NewMenuButton("生成组件", delegate { StartCommand("wincc-component-blueprints"); }));
            AddSettingRow(grid, 22, "流水线", NewMenuButton("一键生成", delegate { StartCommand("agent-pipeline"); }), "草稿", NewMenuButton("生成任务草稿", delegate { CreateAiPrompt(); }));
            AddSettingRow(grid, 23, "WinCC工程", NewMenuButton("生成", delegate { StartCommand("wincc-engineering-scaffold"); }), "仿真", NewMenuButton("生成验证包", delegate { StartCommand("simulation-package"); }));
            AddSettingRow(grid, 24, "编排", NewMenuButton("生成计划", delegate { StartCommand("agent-plan"); }), "队列", NewMenuButton("生成队列", delegate { StartCommand("agent-queue"); }));
            AddSettingRow(grid, 25, "预览", NewMenuButton("查看计划", delegate { ShowAgentTaskPlan(); }), "阶段", NewMenuButton("开始下一步", delegate { StartCommand("queue-start-next"); }));
            AddSettingRow(grid, 26, "预览", NewMenuButton("查看队列", delegate { ShowAgentExecutionQueue(); }), "执行", NewMenuButton("运行当前", delegate { StartCommand("queue-run-current"); }));
            AddSettingRow(grid, 27, "阶段", NewMenuButton("完成当前", delegate { StartCommand("queue-complete-current"); }), "审查", NewMenuButton("生成审查包", delegate { StartCommand("review-package"); }));
            AddSettingRow(grid, 28, "预览", NewMenuButton("查看审查包", delegate { ShowWorkbenchReviewPackage(); }), "总览", NewMenuButton("刷新总览", delegate { StartCommand("workbench-dashboard"); }));
            AddSettingRow(grid, 29, "预览", NewMenuButton("查看总览", delegate { ShowWorkbenchDashboard(); }), "WinCC", NewMenuButton("生成视觉包", delegate { StartCommand("wincc-visual-package"); }));
            AddSettingRow(grid, 30, "WinCC实现", NewMenuButton("生成实现包", delegate { StartCommand("wincc-openness-implementation"); }), "预览", NewMenuButton("查看实现包", delegate { ShowWinccOpennessImplementation(); }));
            AddSettingRow(grid, 31, "仿真回放", NewMenuButton("生成回放", delegate { StartCommand("simulation-replay"); }), "预览", NewMenuButton("查看回放", delegate { ShowSimulationReplay(); }));

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

        private static void AddQuickSettingCell(TableLayoutPanel grid, int column, int row, string labelText, Control control)
        {
            TableLayoutPanel cell = new TableLayoutPanel();
            cell.Dock = DockStyle.Fill;
            cell.Margin = new Padding(2, 1, 2, 1);
            cell.ColumnCount = 2;
            cell.RowCount = 1;
            cell.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 58));
            cell.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));

            Label label = new Label();
            label.Text = labelText;
            label.Dock = DockStyle.Fill;
            label.TextAlign = ContentAlignment.MiddleRight;
            label.ForeColor = MutedInk;
            label.Margin = new Padding(0, 1, 5, 1);
            cell.Controls.Add(label, 0, 0);

            control.Dock = DockStyle.Fill;
            control.Margin = new Padding(0, 3, 0, 3);
            cell.Controls.Add(control, 1, 0);
            grid.Controls.Add(cell, column, row);
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
            statusLabel.Text = "设置位于 工具 > AI平台 / Agent / 工作流 / WinCC 设置";
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

        private static void StyleActionButton(Button button, Color color)
        {
            button.Dock = DockStyle.Fill;
            button.Margin = new Padding(4);
            button.FlatStyle = FlatStyle.Flat;
            button.FlatAppearance.BorderSize = 0;
            button.BackColor = color;
            button.ForeColor = Color.White;
            button.Cursor = Cursors.Hand;
            button.Font = new Font("Microsoft YaHei UI", 9F, FontStyle.Bold);
        }

        private static void StyleCompactButton(Button button)
        {
            button.Dock = DockStyle.Fill;
            button.Height = 30;
            button.Margin = new Padding(3, 2, 3, 2);
            button.Font = new Font("Microsoft YaHei UI", 8.5F, FontStyle.Bold);
        }

        private static void StyleInput(TextBox box)
        {
            box.BorderStyle = BorderStyle.FixedSingle;
            box.BackColor = Color.FromArgb(255, 254, 248);
            box.ForeColor = Ink;
            box.Font = new Font("Microsoft YaHei UI", 9F);
        }

        private static void ConfigureCommandBox(TextBox box, string description)
        {
            box.Width = 220;
            box.AccessibleDescription = description;
            StyleInput(box);
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

                if (mainTabs.TabPages.Count >= 11)
                {
                    mainTabs.SelectedIndex = 10;
                }
                statusLabel.Text = "参考图已加载";
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "参考图加载失败", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }

        private void ApplyQuickSettingsToAdvanced(bool applyWorkflowDefaults)
        {
            if (synchronizingSettings)
            {
                return;
            }

            string previousRouting = SelectedRoutingMode();
            string previousPlatform = SelectedPlatformId();
            if (applyWorkflowDefaults && !loadingWorkflowConfig)
            {
                workflowAutoMode = SelectedText(quickWorkflowBox, "自动选择") == "自动选择";
            }
            try
            {
                synchronizingSettings = true;
                SelectCombo(routingModeBox, quickRoutingModeBox.Text);
                SelectCombo(platformBox, quickPlatformBox.Text);
                SelectCombo(modelBox, quickModelBox.Text);
                SelectCombo(workflowSelectBox, quickWorkflowBox.Text);
            }
            finally
            {
                synchronizingSettings = false;
            }

            if (previousRouting != SelectedRoutingMode() || previousPlatform != SelectedPlatformId())
            {
                ResetAgentSessionForRoutingChange("快速栏路由设置已切换");
            }
            if (applyWorkflowDefaults && !loadingWorkflowConfig)
            {
                ApplyWorkflowDefaults(false);
            }
            SyncQuickSettingsFromAdvanced();
            SaveWorkflowConfig(false);
        }

        private void SyncQuickSettingsFromAdvanced()
        {
            if (synchronizingSettings)
            {
                return;
            }

            try
            {
                synchronizingSettings = true;
                SelectCombo(quickRoutingModeBox, routingModeBox.Text);
                SelectCombo(quickPlatformBox, platformBox.Text);
                SelectCombo(quickModelBox, modelBox.Text);
                SelectCombo(quickWorkflowBox, workflowSelectBox.Text);
            }
            finally
            {
                synchronizingSettings = false;
            }
        }

        private string SaveWorkflowConfig(bool notifyUser)
        {
            if (loadingWorkflowConfig)
            {
                return workflowConfigPath;
            }

            try
            {
                string root = projectRoot;
                if (string.IsNullOrWhiteSpace(root))
                {
                    if (string.IsNullOrWhiteSpace(projectPathBox.Text))
                    {
                        return "";
                    }
                    root = ResolveProjectRoot(projectPathBox.Text);
                }

                string configDir = Path.Combine(root, "PLC_Code", "config");
                Directory.CreateDirectory(configDir);
                workflowConfigPath = Path.Combine(configDir, "ai-workflow.json");

                string safetyMode = SelectedText(safetyModeBox, "克隆编译验证");
                StringBuilder json = new StringBuilder();
                json.AppendLine("{");
                json.AppendLine("  \"schemaVersion\": 2,");
                json.AppendLine("  \"updatedAt\": " + JsonString(DateTime.Now.ToString("o")) + ",");
                json.AppendLine("  \"projectRoot\": " + JsonString(root) + ",");
                json.AppendLine("  \"platform\": {");
                json.AppendLine("    \"routingMode\": " + JsonString(SelectedRoutingMode()) + ",");
                json.AppendLine("    \"selected\": " + JsonString(SelectedPlatformId()) + ",");
                json.AppendLine("    \"sessionPlatform\": " + JsonString(agentSessionPlatform) + ",");
                json.AppendLine("    \"codexCommand\": " + JsonString(codexCommandBox.Text.Trim()) + ",");
                json.AppendLine("    \"claudeCommand\": " + JsonString(claudeCommandBox.Text.Trim()) + ",");
                json.AppendLine("    \"traeCommand\": " + JsonString(traeCommandBox.Text.Trim()) + ",");
                json.AppendLine("    \"qoderCommand\": " + JsonString(qoderCommandBox.Text.Trim()) + ",");
                json.AppendLine("    \"traeProvider\": " + JsonString(traeProviderBox.Text.Trim()));
                json.AppendLine("  },");
                json.AppendLine("  \"routing\": {");
                json.AppendLine("    \"codeModel\": " + JsonString(SelectedText(modelBox, "继承平台/工作流默认")) + ",");
                json.AppendLine("    \"workflow\": " + JsonString(SelectedText(workflowSelectBox, "自动选择")) + ",");
                json.AppendLine("    \"workflowAuto\": " + (workflowAutoMode ? "true" : "false") + ",");
                json.AppendLine("    \"languagePreference\": " + JsonString(SelectedText(languagePreferenceBox, "LAD优先")) + ",");
                json.AppendLine("    \"apiProvider\": " + JsonString(SelectedText(apiProviderBox, "Codex内置")) + ",");
                json.AppendLine("    \"apiBase\": " + JsonString(apiBaseBox.Text.Trim()) + ",");
                json.AppendLine("    \"apiKeyEnvironment\": " + JsonString(EmptyAsDefault(apiKeyEnvBox.Text.Trim(), "OPENAI_API_KEY")));
                json.AppendLine("  },");
                json.AppendLine("  \"agent\": {");
                json.AppendLine("    \"profile\": " + JsonString(SelectedAgentId()) + ",");
                json.AppendLine("    \"search\": " + (agentSearchBox.Checked ? "true" : "false") + ",");
                json.AppendLine("    \"sandbox\": " + JsonString(SelectedAgentSandbox()) + ",");
                json.AppendLine("    \"threadId\": " + JsonString(agentThreadId));
                json.AppendLine("  },");
                json.AppendLine("  \"tia\": {");
                json.AppendLine("    \"sessionMode\": " + JsonString(SelectedText(tiaSessionModeBox, "自动附加")) + ",");
                json.AppendLine("    \"plcName\": " + JsonString(PlcName()) + ",");
                json.AppendLine("    \"stepTimeoutSeconds\": " + WorkflowTimeoutSeconds().ToString());
                json.AppendLine("  },");
                json.AppendLine("  \"safety\": {");
                json.AppendLine("    \"safetyMode\": " + JsonString(safetyMode) + ",");
                json.AppendLine("    \"backupFirst\": true,");
                json.AppendLine("    \"cloneBeforeWrite\": " + (safetyMode == "只生成不写入" ? "false" : "true") + ",");
                json.AppendLine("    \"generateReleasePackage\": " + (safetyMode == "克隆验证并生成发布包" ? "true" : "false") + ",");
                json.AppendLine("    \"allowProductionWrite\": false");
                json.AppendLine("  },");
                json.AppendLine("  \"wincc\": {");
                json.AppendLine("    \"flavor\": " + JsonString(SelectedText(winccFlavorBox, "自动检测")) + ",");
                json.AppendLine("    \"pluginPolicy\": " + JsonString(SelectedText(winccPluginPolicyBox, "自动选择")) + ",");
                json.AppendLine("    \"searchOnline\": true,");
                json.AppendLine("    \"graphqlUrl\": " + JsonString(winccGraphqlUrlBox.Text.Trim()) + ",");
                json.AppendLine("    \"runtimeMcpPath\": " + JsonString(runtimeMcpPathBox.Text.Trim()) + ",");
                json.AppendLine("    \"tiaMcpPath\": " + JsonString(tiaMcpPathBox.Text.Trim()) + ",");
                json.AppendLine("    \"tiaV20UnifiedMcpPath\": " + JsonString(tiaV20UnifiedMcpPathBox.Text.Trim()) + ",");
                json.AppendLine("    \"tiaOpennessManagerPath\": " + JsonString(tiaOpennessManagerPathBox.Text.Trim()) + ",");
                json.AppendLine("    \"showScriptsPath\": " + JsonString(showScriptsPathBox.Text.Trim()) + ",");
                json.AppendLine("    \"tiaViewerPath\": " + JsonString(tiaViewerPathBox.Text.Trim()));
                json.AppendLine("  },");
                json.AppendLine("  \"image\": {");
                json.AppendLine("    \"workflow\": " + JsonString(SelectedText(imageWorkflowBox, "自动")) + ",");
                json.AppendLine("    \"model\": " + JsonString(SelectedText(imageModelBox, "内置imagegen")) + ",");
                json.AppendLine("    \"quality\": " + JsonString(SelectedText(imageQualityBox, "auto")) + ",");
                json.AppendLine("    \"size\": " + JsonString(SelectedText(imageSizeBox, "1536x1024")) + ",");
                json.AppendLine("    \"componentStrategy\": " + JsonString(SelectedText(componentStrategyBox, "自动匹配+自定义")) + ",");
                json.AppendLine("    \"referenceImage\": " + JsonString(referenceImageBox.Text.Trim()));
                json.AppendLine("  },");
                json.AppendLine("  \"ui\": {");
                json.AppendLine("    \"fontFamily\": " + JsonString(SelectedText(fontBox, Font.FontFamily.Name)) + ",");
                json.AppendLine("    \"fontSize\": " + JsonString(SelectedText(fontSizeBox, "10")));
                json.AppendLine("  }");
                json.AppendLine("}");
                File.WriteAllText(workflowConfigPath, json.ToString(), Encoding.UTF8);

                if (notifyUser)
                {
                    statusLabel.Text = "工作流配置已保存";
                    previewBox.Text = ReadText(workflowConfigPath);
                    SelectMainTab(3);
                }
                return workflowConfigPath;
            }
            catch (Exception ex)
            {
                if (notifyUser)
                {
                    MessageBox.Show(ex.Message, "保存工作流配置失败", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                }
                return "";
            }
        }

        private void LoadWorkflowConfig(string root)
        {
            workflowConfigPath = Path.Combine(root, "PLC_Code", "config", "ai-workflow.json");
            if (!File.Exists(workflowConfigPath))
            {
                SyncQuickSettingsFromAdvanced();
                SaveWorkflowConfig(false);
                return;
            }

            try
            {
                loadingWorkflowConfig = true;
                string json = ReadText(workflowConfigPath);
                SelectRoutingMode(JsonStringValue(json, "routingMode", "auto", "platform"));
                SelectPlatformById(JsonStringValue(json, "selected", "auto", "platform"));
                agentSessionPlatform = JsonStringValue(json, "sessionPlatform", "", "platform");
                codexCommandBox.Text = JsonStringValue(json, "codexCommand", "", "platform");
                claudeCommandBox.Text = JsonStringValue(json, "claudeCommand", "", "platform");
                traeCommandBox.Text = JsonStringValue(json, "traeCommand", "", "platform");
                qoderCommandBox.Text = JsonStringValue(json, "qoderCommand", "", "platform");
                traeProviderBox.Text = JsonStringValue(json, "traeProvider", "", "platform");
                string configuredCodeModel = JsonStringValue(json, "codeModel", SelectedText(modelBox, "继承平台/工作流默认"));
                if (configuredCodeModel == "继承 Codex 默认" || configuredCodeModel == "gpt-5" || configuredCodeModel == "gpt-5-codex") { configuredCodeModel = "继承平台/工作流默认"; }
                SelectCombo(modelBox, configuredCodeModel);
                string configuredWorkflow = JsonStringValue(json, "workflow", SelectedText(workflowSelectBox, "自动选择"));
                workflowAutoMode = JsonBoolValue(json, "workflowAuto", configuredWorkflow == "自动选择", "routing");
                SelectCombo(workflowSelectBox, configuredWorkflow);
                SelectCombo(languagePreferenceBox, JsonStringValue(json, "languagePreference", SelectedText(languagePreferenceBox, "LAD优先")));
                SelectCombo(apiProviderBox, JsonStringValue(json, "apiProvider", SelectedText(apiProviderBox, "Codex内置")));
                apiBaseBox.Text = JsonStringValue(json, "apiBase", apiBaseBox.Text);
                apiKeyEnvBox.Text = JsonStringValue(json, "apiKeyEnvironment", apiKeyEnvBox.Text);
                SelectAgentById(JsonStringValue(json, "profile", "auto", "agent"));
                agentSearchBox.Checked = JsonBoolValue(json, "search", true, "agent");
                SelectAgentSandbox(JsonStringValue(json, "sandbox", "workspace-write", "agent"));
                agentThreadId = JsonStringValue(json, "threadId", "", "agent");
                if (!string.IsNullOrWhiteSpace(agentThreadId) && string.IsNullOrWhiteSpace(agentSessionPlatform)) { agentSessionPlatform = "codex"; }
                SelectCombo(tiaSessionModeBox, JsonStringValue(json, "sessionMode", SelectedText(tiaSessionModeBox, "自动附加")));
                plcNameBox.Text = JsonStringValue(json, "plcName", PlcName());
                SelectCombo(timeoutSecondsBox, JsonNumberValue(json, "stepTimeoutSeconds", WorkflowTimeoutSeconds()).ToString());
                SelectCombo(safetyModeBox, JsonStringValue(json, "safetyMode", SelectedText(safetyModeBox, "克隆编译验证")));
                SelectCombo(winccFlavorBox, JsonStringValue(json, "flavor", SelectedText(winccFlavorBox, "自动检测"), "wincc"));
                SelectCombo(winccPluginPolicyBox, JsonStringValue(json, "pluginPolicy", SelectedText(winccPluginPolicyBox, "自动选择"), "wincc"));
                winccGraphqlUrlBox.Text = JsonStringValue(json, "graphqlUrl", winccGraphqlUrlBox.Text, "wincc");
                runtimeMcpPathBox.Text = JsonStringValue(json, "runtimeMcpPath", runtimeMcpPathBox.Text, "wincc");
                tiaMcpPathBox.Text = JsonStringValue(json, "tiaMcpPath", tiaMcpPathBox.Text, "wincc");
                tiaV20UnifiedMcpPathBox.Text = JsonStringValue(json, "tiaV20UnifiedMcpPath", tiaV20UnifiedMcpPathBox.Text, "wincc");
                tiaOpennessManagerPathBox.Text = JsonStringValue(json, "tiaOpennessManagerPath", tiaOpennessManagerPathBox.Text, "wincc");
                showScriptsPathBox.Text = JsonStringValue(json, "showScriptsPath", showScriptsPathBox.Text, "wincc");
                tiaViewerPathBox.Text = JsonStringValue(json, "tiaViewerPath", tiaViewerPathBox.Text, "wincc");
                SelectCombo(imageWorkflowBox, JsonStringValue(json, "workflow", SelectedText(imageWorkflowBox, "自动"), "image"));
                SelectCombo(imageModelBox, JsonStringValue(json, "model", SelectedText(imageModelBox, "内置imagegen")));
                SelectCombo(imageQualityBox, JsonStringValue(json, "quality", SelectedText(imageQualityBox, "auto")));
                SelectCombo(imageSizeBox, JsonStringValue(json, "size", SelectedText(imageSizeBox, "1536x1024")));
                SelectCombo(componentStrategyBox, JsonStringValue(json, "componentStrategy", SelectedText(componentStrategyBox, "自动匹配+自定义")));
                referenceImageBox.Text = JsonStringValue(json, "referenceImage", referenceImageBox.Text);
                SelectCombo(fontBox, JsonStringValue(json, "fontFamily", SelectedText(fontBox, Font.FontFamily.Name)));
                SelectCombo(fontSizeBox, JsonStringValue(json, "fontSize", SelectedText(fontSizeBox, "10")));
            }
            catch (Exception ex)
            {
                statusLabel.Text = "配置读取失败：" + ex.Message;
            }
            finally
            {
                loadingWorkflowConfig = false;
            }
            SyncQuickSettingsFromAdvanced();
            ApplySelectedFont();
        }

        private void ShowWorkflowConfig()
        {
            string path = SaveWorkflowConfig(false);
            if (File.Exists(path))
            {
                ShowFile(path);
                statusLabel.Text = "已打开工作流配置";
            }
        }

        private void UpdatePlatformProbeStatus(string reportPath)
        {
            try
            {
                string json = ReadText(reportPath);
                List<string> ready = new List<string>();
                MatchCollection matches = Regex.Matches(json, "\\\"name\\\"\\s*:\\s*\\\"(?<name>[^\\\"]+)\\\"[\\s\\S]*?\\\"installed\\\"\\s*:\\s*(?<installed>true|false)", RegexOptions.IgnoreCase);
                foreach (Match match in matches)
                {
                    if (string.Equals(match.Groups["installed"].Value, "true", StringComparison.OrdinalIgnoreCase))
                    {
                        ready.Add(match.Groups["name"].Value);
                    }
                }
                platformStatusLabel.Text = ready.Count > 0 ? "可用平台：" + string.Join(" / ", ready.ToArray()) : "未检测到可用AI平台";
                statusLabel.Text = "AI平台检测完成";
                ShowFile(reportPath);
            }
            catch (Exception ex)
            {
                platformStatusLabel.Text = "平台检测结果读取失败";
                statusLabel.Text = ex.Message;
            }
        }

        private void ShowWinccPluginRouting()
        {
            try
            {
                string root = ResolveProjectRoot(projectPathBox.Text);
                string path = Path.Combine(root, "PLC_Code", "wincc", "plugin-routing.json");
                if (!File.Exists(path))
                {
                    statusLabel.Text = "尚未生成WinCC插件路由，正在扫描";
                    StartCommand("wincc-plugins");
                    return;
                }
                ShowFile(path);
                statusLabel.Text = "已打开WinCC插件路由";
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "打开WinCC插件路由失败", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }

        private void ShowAgentTaskPlan()
        {
            try
            {
                string root = ResolveProjectRoot(projectPathBox.Text);
                string path = Path.Combine(root, "PLC_Code", "agent-plans", "latest-plan.md");
                if (!File.Exists(path))
                {
                    statusLabel.Text = "尚未生成任务编排，正在创建";
                    StartCommand("agent-plan");
                    return;
                }
                string text = ReadText(path);
                planBox.Text = text;
                previewBox.Text = text;
                SelectMainTab(1);
                statusLabel.Text = "已打开 Agent 任务编排";
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "打开任务编排失败", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }

        private void ShowAgentExecutionQueue()
        {
            try
            {
                string root = ResolveProjectRoot(projectPathBox.Text);
                string path = Path.Combine(root, "PLC_Code", "agent-queues", "latest", "queue.md");
                if (!File.Exists(path))
                {
                    statusLabel.Text = "尚未生成执行队列，正在创建";
                    StartCommand("agent-queue");
                    return;
                }
                string text = ReadText(path);
                planBox.Text = text;
                previewBox.Text = text;
                SelectMainTab(1);
                statusLabel.Text = "已打开 Agent 执行队列";
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "打开执行队列失败", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }

        private void ShowCurrentQueueStage()
        {
            try
            {
                string root = ResolveProjectRoot(projectPathBox.Text);
                string path = Path.Combine(root, "PLC_Code", "agent-queues", "latest", "current-stage.md");
                if (!File.Exists(path))
                {
                    statusLabel.Text = "尚未开始队列阶段，正在启动下一阶段";
                    StartCommand("queue-start-next");
                    return;
                }
                string text = ReadText(path);
                planBox.Text = text;
                previewBox.Text = text;
                SelectMainTab(1);
                statusLabel.Text = "已打开当前队列阶段";
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "打开当前队列阶段失败", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }

        private void ShowWorkbenchReviewPackage()
        {
            try
            {
                string root = ResolveProjectRoot(projectPathBox.Text);
                string path = Path.Combine(root, "PLC_Code", "review-packages", "latest", "review-summary.md");
                if (!File.Exists(path))
                {
                    statusLabel.Text = "尚未生成工作台审查包，正在创建";
                    StartCommand("review-package");
                    return;
                }
                ShowFile(path);
                statusLabel.Text = "已打开工作台审查包";
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "打开工作台审查包失败", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }

        private void ShowWorkbenchDashboard()
        {
            try
            {
                string root = ResolveProjectRoot(projectPathBox.Text);
                string dashboardPath = Path.Combine(root, "PLC_Code", "workbench", "latest", "dashboard.md");
                string validationPath = Path.Combine(root, "PLC_Code", "workbench", "latest", "validation-summary.md");
                string diffPath = Path.Combine(root, "PLC_Code", "workbench", "latest", "diff-summary.patch");
                string contextPath = Path.Combine(root, "PLC_Code", "workbench", "context", "latest", "agent-context.md");
                string knowledgePath = Path.Combine(root, "PLC_Code", "knowledge", "packs", "latest", "knowledge-brief.md");
                string capabilityPath = Path.Combine(root, "PLC_Code", "workbench", "capabilities", "latest", "capability-map.md");
                if (!File.Exists(dashboardPath))
                {
                    statusLabel.Text = "尚未生成工作台总览，正在创建";
                    StartCommand("workbench-dashboard");
                    return;
                }

                validationBox.Text = File.Exists(validationPath) ? ReadText(validationPath) : ReadText(dashboardPath);
                diffBox.Text = File.Exists(diffPath) ? ReadText(diffPath) : "尚未生成 diff 摘要。";
                contextBox.Text = File.Exists(contextPath) ? ReadText(contextPath) : "尚未生成项目对象模型。";
                knowledgeBox.Text = File.Exists(knowledgePath) ? ReadText(knowledgePath) : "尚未生成任务知识检索包。";
                capabilityBox.Text = File.Exists(capabilityPath) ? ReadText(capabilityPath) : "尚未生成工作台能力矩阵。";
                planBox.Text = ReadText(dashboardPath);
                SelectMainTab(6);
                statusLabel.Text = "已打开工作台总览、Diff 与验证面板";
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "打开工作台总览失败", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }

        private void ShowProjectObjectModel()
        {
            try
            {
                string root = ResolveProjectRoot(projectPathBox.Text);
                string contextPath = Path.Combine(root, "PLC_Code", "workbench", "context", "latest", "agent-context.md");
                string modelPath = Path.Combine(root, "PLC_Code", "workbench", "context", "latest", "project-model.json");
                if (!File.Exists(contextPath))
                {
                    statusLabel.Text = "尚未生成项目对象模型，正在创建";
                    StartCommand("project-model");
                    return;
                }

                contextBox.Text = ReadText(contextPath);
                previewBox.Text = File.Exists(modelPath) ? ReadText(modelPath) : contextBox.Text;
                SelectMainTab(7);
                statusLabel.Text = "已打开项目对象模型和 Agent 上下文包";
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "打开项目对象模型失败", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }

        private void ShowKnowledgePack()
        {
            try
            {
                string root = ResolveProjectRoot(projectPathBox.Text);
                string briefPath = Path.Combine(root, "PLC_Code", "knowledge", "packs", "latest", "knowledge-brief.md");
                string jsonPath = Path.Combine(root, "PLC_Code", "knowledge", "packs", "latest", "knowledge-pack.json");
                if (!File.Exists(briefPath))
                {
                    statusLabel.Text = "尚未生成任务知识检索包，正在创建";
                    StartCommand("knowledge-pack");
                    return;
                }

                knowledgeBox.Text = ReadText(briefPath);
                previewBox.Text = File.Exists(jsonPath) ? ReadText(jsonPath) : knowledgeBox.Text;
                SelectMainTab(8);
                statusLabel.Text = "已打开任务知识检索包";
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "打开任务知识检索包失败", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }

        private void ShowWorkbenchCapabilityMap()
        {
            try
            {
                string root = ResolveProjectRoot(projectPathBox.Text);
                string mapPath = Path.Combine(root, "PLC_Code", "workbench", "capabilities", "latest", "capability-map.md");
                string jsonPath = Path.Combine(root, "PLC_Code", "workbench", "capabilities", "latest", "capability-map.json");
                if (!File.Exists(mapPath))
                {
                    statusLabel.Text = "尚未生成工作台能力矩阵，正在创建";
                    StartCommand("capability-map");
                    return;
                }

                capabilityBox.Text = ReadText(mapPath);
                previewBox.Text = File.Exists(jsonPath) ? ReadText(jsonPath) : capabilityBox.Text;
                SelectMainTab(9);
                statusLabel.Text = "已打开工作台能力矩阵";
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "打开工作台能力矩阵失败", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }

        private void ShowWinccVisualPackage()
        {
            try
            {
                string root = ResolveProjectRoot(projectPathBox.Text);
                string path = Path.Combine(root, "PLC_Code", "wincc", "tasks", "latest", "README.md");
                if (!File.Exists(path))
                {
                    statusLabel.Text = "尚未生成WinCC视觉包，正在创建";
                    StartCommand("wincc-visual-package");
                    return;
                }
                ShowFile(path);
                statusLabel.Text = "已打开WinCC视觉工程包";
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "打开WinCC视觉包失败", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }

        private void ShowPlcChangePackage()
        {
            try
            {
                string root = ResolveProjectRoot(projectPathBox.Text);
                string path = Path.Combine(root, "PLC_Code", "changes", "latest-plc-change-package", "README.md");
                if (!File.Exists(path))
                {
                    statusLabel.Text = "尚未生成PLC改动包，正在创建";
                    StartCommand("plc-change-package");
                    return;
                }
                ShowFile(path);
                statusLabel.Text = "已打开PLC改动包";
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "打开PLC改动包失败", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }

        private void ShowPlcInstructionPlan()
        {
            try
            {
                string root = ResolveProjectRoot(projectPathBox.Text);
                string routePath = Path.Combine(root, "PLC_Code", "plc", "instruction-plans", "latest", "instruction-route-table.md");
                string riskPath = Path.Combine(root, "PLC_Code", "plc", "instruction-plans", "latest", "safety-risk-assessment.md");
                if (!File.Exists(routePath))
                {
                    statusLabel.Text = "尚未生成PLC指令方案，正在创建";
                    StartCommand("plc-instruction-plan");
                    return;
                }
                planBox.Text = ReadText(routePath);
                validationBox.Text = File.Exists(riskPath) ? ReadText(riskPath) : "尚未生成安全风险评估。";
                previewBox.Text = planBox.Text;
                SelectMainTab(1);
                statusLabel.Text = "已打开PLC指令/工艺对象方案";
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "打开PLC指令方案失败", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }

        private void ShowPlcInstructionCookbook()
        {
            try
            {
                string root = ResolveProjectRoot(projectPathBox.Text);
                string cookbookPath = Path.Combine(root, "PLC_Code", "plc", "instruction-cookbook", "latest", "instruction-cookbook.md");
                string jsonPath = Path.Combine(root, "PLC_Code", "plc", "instruction-cookbook", "latest", "instruction-cookbook.json");
                if (!File.Exists(cookbookPath))
                {
                    statusLabel.Text = "尚未生成PLC指令模板库，正在创建";
                    StartCommand("plc-instruction-cookbook");
                    return;
                }

                planBox.Text = ReadText(cookbookPath);
                previewBox.Text = File.Exists(jsonPath) ? ReadText(jsonPath) : planBox.Text;
                SelectMainTab(1);
                statusLabel.Text = "已打开PLC指令模板库";
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "打开PLC指令模板库失败", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }

        private void ShowWinccComponentBlueprints()
        {
            try
            {
                string root = ResolveProjectRoot(projectPathBox.Text);
                string blueprintPath = Path.Combine(root, "PLC_Code", "wincc", "component-blueprints", "latest", "component-blueprints.md");
                string jsonPath = Path.Combine(root, "PLC_Code", "wincc", "component-blueprints", "latest", "component-blueprints.json");
                if (!File.Exists(blueprintPath))
                {
                    statusLabel.Text = "尚未生成WinCC组件蓝图，正在创建";
                    StartCommand("wincc-component-blueprints");
                    return;
                }

                planBox.Text = ReadText(blueprintPath);
                previewBox.Text = File.Exists(jsonPath) ? ReadText(jsonPath) : planBox.Text;
                SelectMainTab(1);
                statusLabel.Text = "已打开WinCC组件蓝图";
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "打开WinCC组件蓝图失败", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }

        private void ShowWinccEngineeringScaffold()
        {
            try
            {
                string root = ResolveProjectRoot(projectPathBox.Text);
                string scaffoldPath = Path.Combine(root, "PLC_Code", "wincc", "engineering-scaffold", "latest", "wincc-engineering-scaffold.md");
                string jsonPath = Path.Combine(root, "PLC_Code", "wincc", "engineering-scaffold", "latest", "wincc-engineering-scaffold.json");
                if (!File.Exists(scaffoldPath))
                {
                    statusLabel.Text = "尚未生成WinCC工程脚手架，正在创建";
                    StartCommand("wincc-engineering-scaffold");
                    return;
                }

                planBox.Text = ReadText(scaffoldPath);
                previewBox.Text = File.Exists(jsonPath) ? ReadText(jsonPath) : planBox.Text;
                SelectMainTab(1);
                statusLabel.Text = "已打开WinCC工程脚手架";
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "打开WinCC工程脚手架失败", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }

        private void ShowWinccOpennessImplementation()
        {
            try
            {
                string root = ResolveProjectRoot(projectPathBox.Text);
                string packagePath = Path.Combine(root, "PLC_Code", "wincc", "openness-implementation", "latest", "README.md");
                string manifestPath = Path.Combine(root, "PLC_Code", "wincc", "openness-implementation", "latest", "implementation-manifest.json");
                if (!File.Exists(packagePath))
                {
                    statusLabel.Text = "尚未生成WinCC Openness实现包，正在创建";
                    StartCommand("wincc-openness-implementation");
                    return;
                }

                planBox.Text = ReadText(packagePath);
                previewBox.Text = File.Exists(manifestPath) ? ReadText(manifestPath) : planBox.Text;
                SelectMainTab(1);
                statusLabel.Text = "已打开WinCC Openness实现包";
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "打开WinCC Openness实现包失败", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }

        private void ShowWinccReadback()
        {
            try
            {
                string root = ResolveProjectRoot(projectPathBox.Text);
                string reportPath = Path.Combine(root, "PLC_Code", "wincc", "readback", "latest", "wincc-readback.json");
                string readmePath = Path.Combine(root, "PLC_Code", "wincc", "readback", "latest", "README.md");
                if (!File.Exists(reportPath) && !File.Exists(readmePath))
                {
                    statusLabel.Text = "尚未生成WinCC读取回读";
                    return;
                }
                previewBox.Text = File.Exists(reportPath) ? ReadText(reportPath) : ReadText(readmePath);
                SelectMainTab(1);
                statusLabel.Text = "已打开WinCC真实读取回读";
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "打开WinCC读取回读失败", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }

        private void ShowWinccImplementationRun()
        {
            try
            {
                string root = ResolveProjectRoot(projectPathBox.Text);
                DirectoryInfo runsRoot = new DirectoryInfo(Path.Combine(root, "PLC_Code", "wincc", "openness-implementation"));
                if (!runsRoot.Exists)
                {
                    statusLabel.Text = "尚未生成WinCC实现运行记录";
                    return;
                }
                DirectoryInfo latest = null;
                foreach (DirectoryInfo directory in runsRoot.GetDirectories())
                {
                    if (directory.Name.Equals("latest", StringComparison.OrdinalIgnoreCase))
                    {
                        continue;
                    }
                    if (latest == null || directory.LastWriteTimeUtc > latest.LastWriteTimeUtc)
                    {
                        latest = directory;
                    }
                }
                if (latest == null)
                {
                    statusLabel.Text = "尚未生成WinCC实现运行记录";
                    return;
                }
                string reportPath = Path.Combine(latest.FullName, "implementation-run.json");
                string readmePath = Path.Combine(latest.FullName, "README.md");
                previewBox.Text = File.Exists(reportPath) ? ReadText(reportPath) : ReadText(readmePath);
                SelectMainTab(1);
                statusLabel.Text = "已打开WinCC克隆实现回读";
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "打开WinCC实现运行记录失败", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }

        private void ShowSimulationPackage()
        {
            try
            {
                string root = ResolveProjectRoot(projectPathBox.Text);
                string packagePath = Path.Combine(root, "PLC_Code", "simulation", "latest", "simulation-package.md");
                string jsonPath = Path.Combine(root, "PLC_Code", "simulation", "latest", "simulation-package.json");
                if (!File.Exists(packagePath))
                {
                    statusLabel.Text = "尚未生成仿真/运行验证包，正在创建";
                    StartCommand("simulation-package");
                    return;
                }

                validationBox.Text = ReadText(packagePath);
                previewBox.Text = File.Exists(jsonPath) ? ReadText(jsonPath) : validationBox.Text;
                SelectMainTab(3);
                statusLabel.Text = "已打开仿真/运行验证包";
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "打开仿真/运行验证包失败", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }

        private void ShowSimulationReplay()
        {
            try
            {
                string root = ResolveProjectRoot(projectPathBox.Text);
                string reportPath = Path.Combine(root, "PLC_Code", "simulation", "replays", "latest", "replay-report.md");
                string jsonPath = Path.Combine(root, "PLC_Code", "simulation", "replays", "latest", "replay-report.json");
                if (!File.Exists(reportPath))
                {
                    statusLabel.Text = "尚未生成仿真回放报告，正在创建";
                    StartCommand("simulation-replay");
                    return;
                }

                validationBox.Text = ReadText(reportPath);
                previewBox.Text = File.Exists(jsonPath) ? ReadText(jsonPath) : validationBox.Text;
                SelectMainTab(6);
                statusLabel.Text = "已打开仿真回放报告";
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "打开仿真回放报告失败", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }

        private void ShowLadPreview()
        {
            try
            {
                string root = ResolveProjectRoot(projectPathBox.Text);
                string path = Path.Combine(root, "PLC_Code", "lad-previews", "latest-lad-preview.md");
                if (!File.Exists(path))
                {
                    statusLabel.Text = "尚未生成LAD预览，正在创建";
                    StartCommand("lad-preview");
                    return;
                }
                ShowFile(path);
                statusLabel.Text = "已打开LAD可读预览";
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "打开LAD预览失败", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }

        private void TogglePreviewEditing()
        {
            previewBox.ReadOnly = !editPreviewBox.Checked;
            previewBox.BackColor = editPreviewBox.Checked ? Color.FromArgb(255, 252, 235) : CodeBack;
            previewBox.ForeColor = editPreviewBox.Checked ? Ink : CodeFore;
            statusLabel.Text = editPreviewBox.Checked ? "文件预览已进入可编辑模式" : "文件预览已切回只读模式";
        }

        private void SaveCurrentPreviewFile()
        {
            try
            {
                if (string.IsNullOrWhiteSpace(currentPreviewPath) || !File.Exists(currentPreviewPath))
                {
                    MessageBox.Show("当前预览不是可保存的文件。", "保存文件", MessageBoxButtons.OK, MessageBoxIcon.Information);
                    return;
                }

                string root = ResolveProjectRoot(projectPathBox.Text);
                string backupDir = Path.Combine(root, "PLC_Code", "file-backups", DateTime.Now.ToString("yyyyMMdd-HHmmss"));
                Directory.CreateDirectory(backupDir);
                string backupPath = Path.Combine(backupDir, Path.GetFileName(currentPreviewPath));
                File.Copy(currentPreviewPath, backupPath, true);
                File.WriteAllText(currentPreviewPath, previewBox.Text, Encoding.UTF8);
                statusLabel.Text = "文件已保存，原文件已备份";
                jobBox.AppendText(Environment.NewLine + "已保存：" + currentPreviewPath + Environment.NewLine + "备份：" + backupPath + Environment.NewLine);
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "保存文件失败", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private static string SelectedText(ComboBox combo, string fallback)
        {
            string value = combo.Text;
            return string.IsNullOrWhiteSpace(value) ? fallback : value;
        }

        private string SelectedRoutingMode()
        {
            return SelectedText(routingModeBox, "自动路由") == "手动指定" ? "manual" : "auto";
        }

        private void SelectRoutingMode(string value)
        {
            SelectCombo(routingModeBox, value == "manual" ? "手动指定" : "自动路由");
        }

        private string SelectedPlatformId()
        {
            string selected = SelectedText(platformBox, "自动选择");
            if (selected == "Codex") { return "codex"; }
            if (selected == "Claude Code") { return "claude-code"; }
            if (selected == "Trae Agent") { return "trae-agent"; }
            if (selected == "Qoder") { return "qoder"; }
            return "auto";
        }

        private void SelectPlatformById(string id)
        {
            string name = "自动选择";
            if (id == "codex") { name = "Codex"; }
            else if (id == "claude-code") { name = "Claude Code"; }
            else if (id == "trae-agent") { name = "Trae Agent"; }
            else if (id == "qoder") { name = "Qoder"; }
            SelectCombo(platformBox, name);
        }

        private void ResetAgentSessionForRoutingChange(string reason)
        {
            if (loadingWorkflowConfig || applyingWorkflowDefaults) { return; }
            if (!string.IsNullOrWhiteSpace(agentThreadId) || !string.IsNullOrWhiteSpace(agentSessionPlatform))
            {
                agentThreadId = "";
                agentSessionPlatform = "";
                activePlatformName = "";
                activePlatformModel = "";
                chatBox.AppendText(Environment.NewLine + "--- " + reason + "，已自动开始新会话 ---" + Environment.NewLine);
            }
        }

        private int WorkflowTimeoutSeconds()
        {
            int value;
            return int.TryParse(SelectedText(timeoutSecondsBox, "600"), out value) ? value : 600;
        }

        private string SelectedAgentId()
        {
            string selected = SelectedText(agentBox, "自动路由 Agent");
            if (selected == "工作台编排 Agent") { return "workbench"; }
            if (selected == "队列执行 Agent") { return "queue-runner"; }
            if (selected == "PLC LAD 工程师") { return "plc-lad"; }
            if (selected == "PLC SCL 工程师") { return "plc-scl"; }
            if (selected == "PLC 高级指令工程师") { return "advanced-plc"; }
            if (selected == "DB 与变量架构师") { return "data-block"; }
            if (selected == "WinCC 画面工程师") { return "wincc"; }
            if (selected == "Openness 自动化工程师") { return "openness"; }
            if (selected == "编译诊断 Agent") { return "diagnostics"; }
            if (selected == "只读审查 Agent") { return "reviewer"; }
            return "auto";
        }

        private void SelectAgentById(string id)
        {
            string name = "自动路由 Agent";
            if (id == "workbench") { name = "工作台编排 Agent"; }
            else if (id == "queue-runner") { name = "队列执行 Agent"; }
            else if (id == "plc-lad") { name = "PLC LAD 工程师"; }
            else if (id == "plc-scl") { name = "PLC SCL 工程师"; }
            else if (id == "advanced-plc") { name = "PLC 高级指令工程师"; }
            else if (id == "data-block") { name = "DB 与变量架构师"; }
            else if (id == "wincc") { name = "WinCC 画面工程师"; }
            else if (id == "openness") { name = "Openness 自动化工程师"; }
            else if (id == "diagnostics") { name = "编译诊断 Agent"; }
            else if (id == "reviewer") { name = "只读审查 Agent"; }
            SelectCombo(agentBox, name);
        }

        private string SelectedAgentSandbox()
        {
            string selected = SelectedText(agentSandboxBox, "工作区读写");
            if (selected == "只读") { return "read-only"; }
            if (selected == "完全访问") { return "danger-full-access"; }
            return "workspace-write";
        }

        private void SelectAgentSandbox(string value)
        {
            if (value == "read-only") { SelectCombo(agentSandboxBox, "只读"); }
            else if (value == "danger-full-access") { SelectCombo(agentSandboxBox, "完全访问"); }
            else { SelectCombo(agentSandboxBox, "工作区读写"); }
        }

        private string SelectedAgentModel()
        {
            string selected = SelectedText(modelBox, "继承平台/工作流默认");
            if (selected.StartsWith("继承", StringComparison.Ordinal) || selected == "自定义模型ID")
            {
                return "inherit";
            }
            return selected;
        }

        private static string JsonString(string value)
        {
            string safe = value ?? "";
            safe = safe.Replace("\\", "\\\\").Replace("\"", "\\\"").Replace("\r", "\\r").Replace("\n", "\\n").Replace("\t", "\\t");
            return "\"" + safe + "\"";
        }

        private static string JsonStringValue(string json, string key, string fallback)
        {
            return JsonStringValue(json, key, fallback, "");
        }

        private static string JsonStringValue(string json, string key, string fallback, string section)
        {
            string source = json ?? "";
            if (!string.IsNullOrWhiteSpace(section))
            {
                Match sectionMatch = Regex.Match(source, "\\\"" + Regex.Escape(section) + "\\\"\\s*:\\s*\\{(?<body>.*?)\\}", RegexOptions.Singleline);
                if (sectionMatch.Success)
                {
                    source = sectionMatch.Groups["body"].Value;
                }
            }
            Match match = Regex.Match(source, "\\\"" + Regex.Escape(key) + "\\\"\\s*:\\s*\\\"(?<value>(?:\\\\.|[^\\\"])*)\\\"", RegexOptions.Singleline);
            return match.Success ? UnescapeJson(match.Groups["value"].Value) : fallback;
        }

        private static int JsonNumberValue(string json, string key, int fallback)
        {
            Match match = Regex.Match(json ?? "", "\\\"" + Regex.Escape(key) + "\\\"\\s*:\\s*(?<value>\\d+)");
            int value;
            return match.Success && int.TryParse(match.Groups["value"].Value, out value) ? value : fallback;
        }

        private static bool JsonBoolValue(string json, string key, bool fallback, string section)
        {
            string source = json ?? "";
            if (!string.IsNullOrWhiteSpace(section))
            {
                Match sectionMatch = Regex.Match(source, "\\\"" + Regex.Escape(section) + "\\\"\\s*:\\s*\\{(?<body>.*?)\\}", RegexOptions.Singleline);
                if (sectionMatch.Success) { source = sectionMatch.Groups["body"].Value; }
            }
            Match match = Regex.Match(source, "\\\"" + Regex.Escape(key) + "\\\"\\s*:\\s*(?<value>true|false)", RegexOptions.IgnoreCase);
            bool value;
            return match.Success && bool.TryParse(match.Groups["value"].Value, out value) ? value : fallback;
        }

        private static string UnescapeJson(string value)
        {
            if (string.IsNullOrEmpty(value))
            {
                return value ?? "";
            }
            StringBuilder builder = new StringBuilder();
            for (int i = 0; i < value.Length; i++)
            {
                char current = value[i];
                if (current != '\\' || i + 1 >= value.Length)
                {
                    builder.Append(current);
                    continue;
                }

                char escaped = value[++i];
                if (escaped == 'n') { builder.Append('\n'); }
                else if (escaped == 'r') { builder.Append('\r'); }
                else if (escaped == 't') { builder.Append('\t'); }
                else if (escaped == 'b') { builder.Append('\b'); }
                else if (escaped == 'f') { builder.Append('\f'); }
                else if (escaped == 'u' && i + 4 < value.Length)
                {
                    int code;
                    string hex = value.Substring(i + 1, 4);
                    if (int.TryParse(hex, System.Globalization.NumberStyles.HexNumber, null, out code))
                    {
                        builder.Append((char)code);
                        i += 4;
                    }
                    else
                    {
                        builder.Append('u');
                    }
                }
                else
                {
                    builder.Append(escaped);
                }
            }
            return builder.ToString();
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
                string workflow = workflowAutoMode ? "自动选择" : SelectedText(workflowSelectBox, "自动选择");
                string inferred = InferWorkflow(request, workflow);

                if (!inferFromTextOnly || workflowAutoMode)
                {
                    SelectCombo(workflowSelectBox, inferred);
                }

                bool hasReferenceImage = File.Exists(referenceImageBox.Text);
                bool winccVisual = inferred.IndexOf("WinCC", StringComparison.OrdinalIgnoreCase) >= 0 || ContainsAny(request, new string[] { "画面", "界面", "hmi", "wincc", "参考图", "截图", "复刻" });
                bool lad = inferred == "LAD编写与验证" || inferred == "DB+程序块协同";

                SelectAgentForWorkflow(inferred);

                if (winccVisual)
                {
                    SelectCombo(imageWorkflowBox, hasReferenceImage ? "图生图/参考图" : "文生图");
                    SelectCombo(imageModelBox, "内置imagegen");
                    SelectCombo(imageQualityBox, "high");
                    SelectCombo(imageSizeBox, "1536x1024");
                    SelectCombo(componentStrategyBox, hasReferenceImage ? "自动匹配+自定义" : "Faceplate优先");
                    statusLabel.Text = hasReferenceImage ? "已按参考图任务推荐 Agent 与平台路由" : "已按WinCC设计任务推荐 Agent 与平台路由";
                }
                else if (lad)
                {
                    SelectCombo(imageWorkflowBox, "无图像");
                    SelectCombo(componentStrategyBox, "标准WinCC组件");
                    statusLabel.Text = "已按PLC/LAD任务推荐 Agent 与平台路由";
                }
                else if (inferred == "SCL编写与验证")
                {
                    SelectCombo(imageWorkflowBox, "无图像");
                    statusLabel.Text = "已按SCL任务推荐 Agent 与平台路由";
                }
                else if (ContainsAny(request, new string[] { "故障", "报错", "诊断", "openness" }))
                {
                    SelectCombo(imageWorkflowBox, "无图像");
                    statusLabel.Text = "已按诊断任务推荐 Agent 与平台路由";
                }
                if (SelectedRoutingMode() == "auto") { SelectPlatformById("auto"); }
            }
            finally
            {
                applyingWorkflowDefaults = false;
            }
            SyncQuickSettingsFromAdvanced();
        }

        private void SelectAgentForWorkflow(string workflow)
        {
            if (workflow == "工作台自动开发") { SelectAgentById("workbench"); }
            else if (workflow == "Agent执行队列") { SelectAgentById("queue-runner"); }
            else if (workflow == "LAD编写与验证") { SelectAgentById("plc-lad"); }
            else if (workflow == "SCL编写与验证") { SelectAgentById("plc-scl"); }
            else if (workflow == "PLC高级指令与工艺对象") { SelectAgentById("advanced-plc"); }
            else if (workflow == "DB+程序块协同") { SelectAgentById("data-block"); }
            else if (workflow == "WinCC画面生成" || workflow == "WinCC参考图复刻") { SelectAgentById("wincc"); }
            else if (workflow == "Openness自动化") { SelectAgentById("openness"); }
            else if (workflow == "故障诊断") { SelectAgentById("diagnostics"); }
            else if (workflow == "只读审查" || workflow == "安全风险评估") { SelectAgentById("reviewer"); }
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
            if (ContainsAny(request, new string[] { "执行队列", "队列", "阶段", "证据", "stage", "queue" }))
            {
                return "Agent执行队列";
            }
            if (ContainsAny(request, new string[] { "工作台", "agent应用", "智能体应用", "替代codex", "替代编辑器" }))
            {
                return "工作台自动开发";
            }
            if (ContainsAny(request, new string[] { "wincc", "hmi", "画面", "界面", "faceplate", "报警画面", "趋势" }))
            {
                return "WinCC画面生成";
            }
            if (ContainsAny(request, new string[] { "高级指令", "工艺对象", "technology", "motion", "pid", "modbus", "通信", "伺服", "变频" }))
            {
                return "PLC高级指令与工艺对象";
            }
            if (ContainsAny(request, new string[] { "安全", "风险", "联锁审查", "安全评估" }))
            {
                return "安全风险评估";
            }
            if (ContainsAny(request, new string[] { "工业化", "成熟项目", "架构重构", "标准化改造" }))
            {
                return "工业化重构";
            }
            if (ContainsAny(request, new string[] { "db", "变量块", "数据块" }))
            {
                return "DB+程序块协同";
            }
            if (ContainsAny(request, new string[] { "scl", "结构化文本", "算法", "数组", "字符串" }))
            {
                return "SCL编写与验证";
            }
            if (ContainsAny(request, new string[] { "lad", "梯形图", "程序块", "导入", "编译验证" }))
            {
                return "LAD编写与验证";
            }
            if (ContainsAny(request, new string[] { "故障", "报错", "诊断", "异常" }))
            {
                return "故障诊断";
            }
            if (ContainsAny(request, new string[] { "openness", "开放性", "publicapi" }))
            {
                return "Openness自动化";
            }
            if (ContainsAny(request, new string[] { "审查", "review", "只读检查" }))
            {
                return "只读审查";
            }
            return "读取项目并总结";
        }

        private static string WorkflowId(string workflow)
        {
            if (workflow == "LAD编写与验证") { return "plc-lad"; }
            if (workflow == "工作台自动开发") { return "agent-workbench"; }
            if (workflow == "Agent执行队列") { return "agent-queue"; }
            if (workflow == "PLC高级指令与工艺对象") { return "advanced-plc"; }
            if (workflow == "SCL编写与验证") { return "plc-scl"; }
            if (workflow == "DB+程序块协同") { return "data-contract"; }
            if (workflow == "WinCC画面生成") { return "wincc-visual"; }
            if (workflow == "WinCC参考图复刻") { return "wincc-reference"; }
            if (workflow == "Openness自动化") { return "openness"; }
            if (workflow == "安全风险评估") { return "safety-risk"; }
            if (workflow == "故障诊断") { return "diagnostics"; }
            if (workflow == "工业化重构") { return "industrial-refactor"; }
            if (workflow == "只读审查") { return "review"; }
            return "project-read";
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
            else if (combo.DropDownStyle != ComboBoxStyle.DropDownList)
            {
                combo.Text = value;
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
                diffBox.Font = codeFont;
                validationBox.Font = uiFont;
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
                LoadWorkflowConfig(resolved);
                currentLadSpecPath = Path.Combine(resolved, "PLC_Code", "lad-editor", "latest-network.json");
                if (File.Exists(currentLadSpecPath))
                {
                    LoadLadEditorFromSpec();
                }
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
            if (mainTabs.TabPages.Count >= 5)
            {
                mainTabs.SelectedIndex = 4;
            }
        }

        private void ShowFile(string path)
        {
            try
            {
                currentPreviewPath = File.Exists(path) ? path : "";
                previewBox.Text = ReadText(path);
                if (mainTabs.TabPages.Count >= 4)
                {
                    mainTabs.SelectedIndex = 3;
                }
            }
            catch (Exception ex)
            {
                currentPreviewPath = "";
                previewBox.Text = ex.Message;
            }
        }

        private void BrowseAgentAttachments()
        {
            try
            {
                string root = ResolveProjectRoot(projectPathBox.Text);
                OpenFileDialog dialog = new OpenFileDialog();
                dialog.Title = "上传给 Agent 的项目资料";
                dialog.Filter = "支持的工程资料|*.png;*.jpg;*.jpeg;*.webp;*.gif;*.pdf;*.docx;*.xlsx;*.csv;*.txt;*.md;*.xml;*.scl;*.udt;*.db;*.json;*.log|所有文件|*.*";
                dialog.Multiselect = true;
                if (dialog.ShowDialog(this) != DialogResult.OK) { return; }

                string targetRoot = Path.Combine(root, "PLC_Code", "agent-attachments", DateTime.Now.ToString("yyyyMMdd"));
                Directory.CreateDirectory(targetRoot);
                foreach (string source in dialog.FileNames)
                {
                    string fileName = Path.GetFileName(source);
                    string destination = Path.Combine(targetRoot, fileName);
                    if (File.Exists(destination))
                    {
                        destination = Path.Combine(targetRoot, Path.GetFileNameWithoutExtension(fileName) + "-" + DateTime.Now.ToString("HHmmssfff") + Path.GetExtension(fileName));
                    }
                    File.Copy(source, destination, false);
                    agentAttachments.Add(destination);

                    string extension = Path.GetExtension(destination).ToLowerInvariant();
                    if (string.IsNullOrWhiteSpace(referenceImageBox.Text) && (extension == ".png" || extension == ".jpg" || extension == ".jpeg" || extension == ".webp"))
                    {
                        referenceImageBox.Text = destination;
                    }
                }
                UpdateAgentAttachmentLabel();
                statusLabel.Text = "已上传 " + dialog.FileNames.Length.ToString() + " 个附件";
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "附件上传失败", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }

        private void ClearAgentAttachments()
        {
            agentAttachments.Clear();
            UpdateAgentAttachmentLabel();
            statusLabel.Text = "本次待发送附件已清空";
        }

        private void UpdateAgentAttachmentLabel()
        {
            if (agentAttachments.Count == 0)
            {
                agentAttachmentLabel.Text = "附件：无，可上传图片、PDF、文档、源码或导出 XML";
                return;
            }
            List<string> names = new List<string>();
            foreach (string path in agentAttachments) { names.Add(Path.GetFileName(path)); }
            agentAttachmentLabel.Text = "附件(" + agentAttachments.Count.ToString() + ")：" + string.Join("；", names.ToArray());
        }

        private void NewAgentSession()
        {
            if (agentProcess != null && !agentProcess.HasExited)
            {
                MessageBox.Show("请先等待当前 Agent 回合完成或点击停止。", "Agent 正在运行", MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }
            agentThreadId = "";
            agentSessionPlatform = "";
            activePlatformName = "";
            activePlatformModel = "";
            platformStatusLabel.Text = "平台：等待下一次路由";
            chatBox.AppendText(Environment.NewLine + "--- 已新建 Agent 会话 ---" + Environment.NewLine);
            SaveWorkflowConfig(false);
            statusLabel.Text = "已新建 Agent 会话";
        }

        private void SendAgentMessage()
        {
            if (agentProcess != null && !agentProcess.HasExited)
            {
                MessageBox.Show("当前 Agent 仍在处理上一条消息。", "Agent 正在运行", MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }

            string userMessage = requestBox.Text.Trim();
            if (string.IsNullOrWhiteSpace(userMessage))
            {
                MessageBox.Show("请输入要发送给 Agent 的内容。", "消息为空", MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }

            try
            {
                string root = ResolveProjectRoot(projectPathBox.Text);
                ApplyWorkflowDefaults(true);
                string agentScript = Path.Combine(Path.GetDirectoryName(invokeScript), "invoke-ai-platform-agent.ps1");
                if (!File.Exists(agentScript)) { throw new FileNotFoundException("未找到统一 AI 平台适配脚本。", agentScript); }

                string configPath = SaveWorkflowConfig(false);
                string runRoot = Path.Combine(root, "PLC_Code", "agent-sessions", DateTime.Now.ToString("yyyyMMdd-HHmmss-fff"));
                Directory.CreateDirectory(runRoot);
                string promptPath = Path.Combine(runRoot, "user-message.txt");
                string manifestPath = Path.Combine(runRoot, "attachments.txt");
                agentStdoutPath = Path.Combine(runRoot, "agent.jsonl");
                agentStderrPath = Path.Combine(runRoot, "agent.stderr.log");
                File.WriteAllText(promptPath, userMessage, Encoding.UTF8);
                File.WriteAllLines(manifestPath, agentAttachments.ToArray(), Encoding.UTF8);
                File.WriteAllText(agentStdoutPath, "", Encoding.UTF8);
                File.WriteAllText(agentStderrPath, "", Encoding.UTF8);

                List<string> args = new List<string>();
                args.Add("-NoProfile");
                args.Add("-ExecutionPolicy");
                args.Add("Bypass");
                args.Add("-File");
                args.Add(agentScript);
                args.Add("-ProjectPath");
                args.Add(root);
                args.Add("-PromptFile");
                args.Add(promptPath);
                args.Add("-AgentId");
                args.Add(SelectedAgentId());
                args.Add("-Workflow");
                args.Add(WorkflowId(SelectedText(workflowSelectBox, "读取项目并总结")));
                args.Add("-RoutingMode");
                args.Add(SelectedRoutingMode());
                args.Add("-Platform");
                args.Add(SelectedPlatformId());
                args.Add("-Model");
                args.Add(SelectedAgentModel());
                args.Add("-Sandbox");
                args.Add(SelectedAgentSandbox());
                args.Add("-AttachmentManifest");
                args.Add(manifestPath);
                if (!string.IsNullOrWhiteSpace(configPath))
                {
                    args.Add("-WorkflowConfigPath");
                    args.Add(configPath);
                }
                if (agentSearchBox.Checked) { args.Add("-Search"); }
                if (!string.IsNullOrWhiteSpace(agentThreadId))
                {
                    args.Add("-SessionId");
                    args.Add(agentThreadId);
                    if (!string.IsNullOrWhiteSpace(agentSessionPlatform))
                    {
                        args.Add("-SessionPlatform");
                        args.Add(agentSessionPlatform);
                    }
                }

                chatBox.AppendText(Environment.NewLine + "你 · " + SelectedText(agentBox, "自动路由 Agent") + " · " + SelectedText(platformBox, "自动选择") + Environment.NewLine + userMessage + Environment.NewLine);
                if (agentAttachments.Count > 0)
                {
                    chatBox.AppendText("附件：" + agentAttachmentLabel.Text + Environment.NewLine);
                }
                chatBox.AppendText(Environment.NewLine + "Agent 正在处理..." + Environment.NewLine);
                mainTabs.SelectedIndex = 0;

                ProcessStartInfo start = new ProcessStartInfo();
                start.FileName = "powershell.exe";
                start.Arguments = JoinArgs(args);
                start.WorkingDirectory = root;
                start.UseShellExecute = false;
                start.CreateNoWindow = true;
                start.RedirectStandardOutput = true;
                start.RedirectStandardError = true;
                start.StandardOutputEncoding = Encoding.UTF8;
                start.StandardErrorEncoding = Encoding.UTF8;

                Process process = new Process();
                process.StartInfo = start;
                process.EnableRaisingEvents = true;
                process.OutputDataReceived += delegate (object sender, DataReceivedEventArgs eventArgs)
                {
                    if (eventArgs.Data == null) { return; }
                    AppendOutput(agentStdoutPath, eventArgs.Data);
                    HandleAgentJsonLine(eventArgs.Data);
                };
                process.ErrorDataReceived += delegate (object sender, DataReceivedEventArgs eventArgs)
                {
                    if (eventArgs.Data == null) { return; }
                    AppendOutput(agentStderrPath, eventArgs.Data);
                    AppendAgentLog("[stderr] " + eventArgs.Data);
                };
                process.Exited += delegate { AgentProcessExited(process); };
                agentProcess = process;
                sendAgentButton.Enabled = false;
                stopAgentButton.Enabled = true;
                statusLabel.Text = "Agent 路由与执行中";
                platformStatusLabel.Text = "平台：正在选择...";
                jobBox.Text = "Agent 会话目录：" + runRoot + Environment.NewLine + "路由模式：" + SelectedText(routingModeBox, "自动路由") + Environment.NewLine + "请求平台：" + SelectedText(platformBox, "自动选择") + Environment.NewLine + "Agent：" + SelectedText(agentBox, "自动路由 Agent") + Environment.NewLine + "模型：" + SelectedAgentModel() + Environment.NewLine + "工作流：" + WorkflowId(SelectedText(workflowSelectBox, "读取项目并总结")) + Environment.NewLine;
                process.Start();
                process.BeginOutputReadLine();
                process.BeginErrorReadLine();
                requestBox.Clear();
                agentAttachments.Clear();
                UpdateAgentAttachmentLabel();
            }
            catch (Exception ex)
            {
                sendAgentButton.Enabled = true;
                stopAgentButton.Enabled = false;
                MessageBox.Show(ex.Message, "Agent 启动失败", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private void HandleAgentJsonLine(string line)
        {
            if (Regex.IsMatch(line, "\\\"type\\\"\\s*:\\s*\\\"platform\\.selected\\\"", RegexOptions.IgnoreCase))
            {
                string platformId = JsonStringValue(line, "platform", "");
                string platformName = JsonStringValue(line, "platform_name", platformId);
                string platformModel = JsonStringValue(line, "model", "inherit");
                string routedAgent = JsonStringValue(line, "agent", SelectedAgentId());
                if (!string.IsNullOrWhiteSpace(agentSessionPlatform) && agentSessionPlatform != platformId)
                {
                    agentThreadId = "";
                }
                agentSessionPlatform = platformId;
                activePlatformName = platformName;
                activePlatformModel = platformModel;
                BeginInvoke((Action)delegate
                {
                    platformStatusLabel.Text = "平台：" + platformName + " · 模型：" + platformModel + " · Agent：" + routedAgent;
                    statusLabel.Text = "已路由到 " + platformName;
                    SaveWorkflowConfig(false);
                });
            }

            Match threadMatch = Regex.Match(line, "\\\"type\\\"\\s*:\\s*\\\"thread\\.started\\\".*?\\\"thread_id\\\"\\s*:\\s*\\\"(?<id>[^\\\"]+)\\\"");
            if (threadMatch.Success)
            {
                agentThreadId = threadMatch.Groups["id"].Value;
                BeginInvoke((Action)delegate { SaveWorkflowConfig(false); });
            }

            Match messageMatch = Regex.Match(line, "\\\"type\\\"\\s*:\\s*\\\"item\\.completed\\\".*?\\\"type\\\"\\s*:\\s*\\\"agent_message\\\".*?\\\"text\\\"\\s*:\\s*\\\"(?<text>(?:\\\\.|[^\\\"])*)\\\"", RegexOptions.Singleline);
            if (messageMatch.Success)
            {
                string message = UnescapeJson(messageMatch.Groups["text"].Value);
                BeginInvoke((Action)delegate
                {
                    string heading = string.IsNullOrWhiteSpace(activePlatformName) ? SelectedText(agentBox, "Agent") : activePlatformName + " · " + SelectedText(agentBox, "Agent");
                    chatBox.AppendText(Environment.NewLine + heading + Environment.NewLine + message + Environment.NewLine);
                    chatBox.SelectionStart = chatBox.TextLength;
                    chatBox.ScrollToCaret();
                });
            }
            AppendAgentLog(line);
        }

        private void AppendAgentLog(string line)
        {
            try
            {
                BeginInvoke((Action)delegate
                {
                    jobBox.AppendText(line + Environment.NewLine);
                    if (jobBox.TextLength > 80000) { jobBox.Text = jobBox.Text.Substring(jobBox.TextLength - 60000); }
                    jobBox.SelectionStart = jobBox.TextLength;
                    jobBox.ScrollToCaret();
                });
            }
            catch
            {
            }
        }

        private void AgentProcessExited(Process process)
        {
            try
            {
                int exitCode = process.ExitCode;
                BeginInvoke((Action)delegate
                {
                    if (agentProcess == process) { agentProcess = null; }
                    sendAgentButton.Enabled = true;
                    stopAgentButton.Enabled = false;
                    statusLabel.Text = exitCode == 0 ? "Agent 回合完成" : "Agent 失败，ExitCode=" + exitCode.ToString();
                    if (exitCode != 0 && File.Exists(agentStderrPath))
                    {
                        chatBox.AppendText(Environment.NewLine + "[Agent 错误]" + Environment.NewLine + Tail(ReadText(agentStderrPath), 3000) + Environment.NewLine);
                    }
                    SaveWorkflowConfig(false);
                });
            }
            catch
            {
            }
        }

        private void StopAgent()
        {
            if (agentProcess == null || agentProcess.HasExited) { return; }
            try
            {
                ProcessStartInfo stop = new ProcessStartInfo();
                stop.FileName = "taskkill.exe";
                stop.Arguments = "/PID " + agentProcess.Id.ToString() + " /T /F";
                stop.UseShellExecute = false;
                stop.CreateNoWindow = true;
                Process.Start(stop);
                statusLabel.Text = "正在停止 Agent";
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "停止 Agent 失败", MessageBoxButtons.OK, MessageBoxIcon.Warning);
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
                string configPath = SaveWorkflowConfig(false);
                List<string> args = BuildCommandArgs(command, root, configPath);
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
                // Windows PowerShell 5.1 writes redirected command output using the
                // active Chinese console code page; decode it explicitly so project
                // paths and diagnostics remain readable in the workbench.
                start.StandardOutputEncoding = Encoding.GetEncoding(936);
                start.StandardErrorEncoding = Encoding.GetEncoding(936);

                currentProcess = new Process();
                currentProcess.StartInfo = start;
                currentProcess.OutputDataReceived += delegate (object sender, DataReceivedEventArgs e) { AppendOutput(currentStdoutPath, e.Data); };
                currentProcess.ErrorDataReceived += delegate (object sender, DataReceivedEventArgs e) { AppendOutput(currentStderrPath, e.Data); };
                currentProcess.EnableRaisingEvents = true;
                currentProcess.Exited += delegate
                {
                    BeginInvoke((Action)delegate
                    {
                        int exitCode = currentProcess.ExitCode;
                        statusLabel.Text = (exitCode == 0 ? "完成" : "未完成/已阻断") + "，ExitCode=" + exitCode;
                        RefreshCurrentJobTail();
                        RefreshRuns();
                        if (command == "wincc-plugins" && currentProcess.ExitCode == 0)
                        {
                            ShowWinccPluginRouting();
                        }
                        if (command == "agent-plan" && currentProcess.ExitCode == 0)
                        {
                            ShowAgentTaskPlan();
                        }
                        if (command == "agent-queue" && currentProcess.ExitCode == 0)
                        {
                            ShowAgentExecutionQueue();
                        }
                        if (command.StartsWith("queue-", StringComparison.OrdinalIgnoreCase) && currentProcess.ExitCode == 0)
                        {
                            ShowCurrentQueueStage();
                        }
                        if (command == "queue-run-current" && currentProcess.ExitCode == 0)
                        {
                            StartCommand("workbench-dashboard");
                        }
                        if (command == "agent-pipeline" && currentProcess.ExitCode == 0)
                        {
                            ShowWorkbenchDashboard();
                        }
                        if (command == "project-model" && currentProcess.ExitCode == 0)
                        {
                            ShowProjectObjectModel();
                        }
                        if (command == "knowledge-pack" && currentProcess.ExitCode == 0)
                        {
                            ShowKnowledgePack();
                        }
                        if (command == "capability-map" && currentProcess.ExitCode == 0)
                        {
                            ShowWorkbenchCapabilityMap();
                        }
                        if (command == "review-package" && currentProcess.ExitCode == 0)
                        {
                            ShowWorkbenchReviewPackage();
                        }
                        if (command == "workbench-dashboard" && currentProcess.ExitCode == 0)
                        {
                            ShowWorkbenchDashboard();
                        }
                        if (command == "wincc-visual-package" && currentProcess.ExitCode == 0)
                        {
                            ShowWinccVisualPackage();
                        }
                        if (command == "lad-preview" && currentProcess.ExitCode == 0)
                        {
                            ShowLadPreview();
                        }
                        if (command == "lad-scaffold" && currentProcess.ExitCode == 0)
                        {
                            LoadLadEditorFromSpec();
                            SelectMainTab(11);
                            ladEditorStatusLabel.Text = "已载入 LAD JSON 模板：" + currentLadSpecPath;
                        }
                        if (command == "write-lad-network" && currentProcess.ExitCode == 0)
                        {
                            inputXmlBox.Text = currentLadGeneratedXmlPath;
                            ShowFile(currentLadGeneratedXmlPath);
                            SelectMainTab(11);
                            ladEditorStatusLabel.Text = "LAD XML 已生成，可点击“校验XML”或“克隆验证”。";
                            BuildProjectTree();
                        }
                        if (command == "lad-validate" && currentProcess.ExitCode == 0)
                        {
                            ladEditorStatusLabel.Text = "LAD XML 校验通过。";
                        }
                        if (command == "plc-change-package" && currentProcess.ExitCode == 0)
                        {
                            ShowPlcChangePackage();
                        }
                        if (command == "plc-instruction-cookbook" && currentProcess.ExitCode == 0)
                        {
                            ShowPlcInstructionCookbook();
                        }
                        if (command == "plc-instruction-plan" && currentProcess.ExitCode == 0)
                        {
                            ShowPlcInstructionPlan();
                        }
                        if (command == "wincc-component-blueprints" && currentProcess.ExitCode == 0)
                        {
                            ShowWinccComponentBlueprints();
                        }
                        if (command == "wincc-engineering-scaffold" && currentProcess.ExitCode == 0)
                        {
                            ShowWinccEngineeringScaffold();
                        }
                        if (command == "wincc-openness-implementation" && currentProcess.ExitCode == 0)
                        {
                            ShowWinccOpennessImplementation();
                        }
                        if (command == "wincc-read-cycle")
                        {
                            ShowWinccReadback();
                        }
                        if (command == "wincc-apply-clone")
                        {
                            ShowWinccImplementationRun();
                        }
                        if (command == "simulation-package" && currentProcess.ExitCode == 0)
                        {
                            ShowSimulationPackage();
                        }
                        if (command == "simulation-replay" && currentProcess.ExitCode == 0)
                        {
                            ShowSimulationReplay();
                        }
                        if (command == "probe-ai-platforms" && currentProcess.ExitCode == 0)
                        {
                            UpdatePlatformProbeStatus(currentStdoutPath);
                        }
                    });
                };

                jobBox.Text = "启动命令：" + command + Environment.NewLine + start.Arguments + Environment.NewLine + "工作流配置：" + configPath + Environment.NewLine + "日志：" + currentStdoutPath + Environment.NewLine;
                if (mainTabs.TabPages.Count >= 2)
                {
                    mainTabs.SelectedIndex = 2;
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

        private List<string> BuildCommandArgs(string command, string root, string configPath)
        {
            List<string> args = new List<string>();
            if (command == "doctor")
            {
                args.Add("doctor");
                args.Add("-ProjectPath");
                args.Add(root);
            }
            else if (command == "probe-ai-platforms")
            {
                args.Add("probe-ai-platforms");
                AddWorkflowConfigArg(args, configPath);
            }
            else if (command == "read-cycle-skip")
            {
                args.AddRange(new string[] { "read-cycle", "-ProjectPath", root, "-SkipExport" });
                AddReadCycleSessionArgs(args);
                AddWorkflowConfigArg(args, configPath);
            }
            else if (command == "read-cycle-full")
            {
                args.AddRange(new string[] { "read-cycle", "-ProjectPath", root });
                AddReadCycleSessionArgs(args);
                AddWorkflowConfigArg(args, configPath);
            }
            else if (command == "list-blocks")
            {
                args.AddRange(new string[] { "list-blocks", "--project", root, "--plc", PlcName() });
                args.Add(SelectedText(tiaSessionModeBox, "自动附加") == "显示TIA界面" ? "--ui" : "--attach");
            }
            else if (command == "lad-preview")
            {
                if (string.IsNullOrWhiteSpace(inputXmlBox.Text) || !File.Exists(inputXmlBox.Text))
                {
                    throw new FileNotFoundException("请先在项目树中选择一个LAD XML文件。", inputXmlBox.Text);
                }
                string previewDir = Path.Combine(root, "PLC_Code", "lad-previews");
                Directory.CreateDirectory(previewDir);
                string latest = Path.Combine(previewDir, "latest-lad-preview.md");
                args.AddRange(new string[] { "summarize-lad", "-Path", inputXmlBox.Text, "-OutputPath", latest });
            }
            else if (command == "lad-scaffold")
            {
                string directory = Path.Combine(root, "PLC_Code", "lad-editor");
                Directory.CreateDirectory(directory);
                currentLadSpecPath = Path.Combine(directory, "latest-network.json");
                args.AddRange(new string[] {
                    "scaffold-lad-network-json",
                    "-OutputPath", currentLadSpecPath,
                    "-Title", string.IsNullOrWhiteSpace(ladTitleBox.Text) ? "LAD network" : ladTitleBox.Text.Trim(),
                    "-Comment", ladCommentBox.Text.Trim()
                });
            }
            else if (command == "lad-validate")
            {
                string candidate = File.Exists(currentLadGeneratedXmlPath) ? currentLadGeneratedXmlPath : inputXmlBox.Text.Trim();
                if (string.IsNullOrWhiteSpace(candidate) || !File.Exists(candidate))
                {
                    throw new FileNotFoundException("请先生成或选择要校验的 LAD XML。", candidate);
                }
                args.AddRange(new string[] { "validate-lad", "-Path", candidate });
            }
            else if (command == "write-lad-network")
            {
                if (string.IsNullOrWhiteSpace(inputXmlBox.Text) || !File.Exists(inputXmlBox.Text))
                {
                    throw new FileNotFoundException("请先选择目标 LAD XML。", inputXmlBox.Text);
                }
                if (string.IsNullOrWhiteSpace(currentLadSpecPath) || !File.Exists(currentLadSpecPath))
                {
                    throw new FileNotFoundException("请先保存 LAD JSON 规格。", currentLadSpecPath);
                }
                int networkIndex;
                if (!int.TryParse(ladNetworkIndexBox.Text.Trim(), out networkIndex) || networkIndex < 1)
                {
                    throw new InvalidOperationException("网络编号必须是大于0的整数。");
                }
                if (string.IsNullOrWhiteSpace(currentLadGeneratedXmlPath))
                {
                    currentLadGeneratedXmlPath = Path.Combine(root, "PLC_Code", "lad-editor", "latest.generated.xml");
                }
                Directory.CreateDirectory(Path.GetDirectoryName(currentLadGeneratedXmlPath));
                args.AddRange(new string[] {
                    "write-lad-network",
                    "-TargetXml", inputXmlBox.Text.Trim(),
                    "-SpecPath", currentLadSpecPath,
                    "-OutputXml", currentLadGeneratedXmlPath,
                    "-NetworkIndex", networkIndex.ToString()
                });
            }
            else if (command == "plc-change-package")
            {
                args.AddRange(new string[] { "plc-change-package", "-ProjectPath", root, "-TaskText", requestBox.Text.Trim(), "-Workflow", WorkflowId(SelectedText(workflowSelectBox, "读取项目并总结")) });
                AddWorkflowConfigArg(args, configPath);
                if (!string.IsNullOrWhiteSpace(inputXmlBox.Text) && File.Exists(inputXmlBox.Text))
                {
                    args.Add("-SourceXml");
                    args.Add(inputXmlBox.Text);
                }
            }
            else if (command == "agent-pipeline")
            {
                args.AddRange(new string[] { "agent-pipeline", "-ProjectPath", root, "-TaskText", requestBox.Text.Trim() });
                AddWorkflowConfigArg(args, configPath);
                if (!string.IsNullOrWhiteSpace(inputXmlBox.Text) && File.Exists(inputXmlBox.Text))
                {
                    args.Add("-SourceXml");
                    args.Add(inputXmlBox.Text);
                }
                if (File.Exists(referenceImageBox.Text.Trim()))
                {
                    args.Add("-ReferenceImagePath");
                    args.Add(referenceImageBox.Text.Trim());
                }
            }
            else if (command == "project-model")
            {
                args.AddRange(new string[] { "project-model", "-ProjectPath", root, "-TaskText", requestBox.Text.Trim() });
                AddWorkflowConfigArg(args, configPath);
            }
            else if (command == "knowledge-pack")
            {
                args.AddRange(new string[] { "knowledge-pack", "-ProjectPath", root, "-TaskText", requestBox.Text.Trim(), "-RefreshOnline" });
                AddWorkflowConfigArg(args, configPath);
            }
            else if (command == "capability-map")
            {
                args.AddRange(new string[] { "capability-map", "-ProjectPath", root, "-TaskText", requestBox.Text.Trim() });
                AddWorkflowConfigArg(args, configPath);
            }
            else if (command == "plc-instruction-plan")
            {
                args.AddRange(new string[] { "plc-instruction-plan", "-ProjectPath", root, "-TaskText", requestBox.Text.Trim() });
                AddWorkflowConfigArg(args, configPath);
                if (!string.IsNullOrWhiteSpace(inputXmlBox.Text) && File.Exists(inputXmlBox.Text))
                {
                    args.Add("-SourceXml");
                    args.Add(inputXmlBox.Text);
                }
            }
            else if (command == "plc-instruction-cookbook")
            {
                args.AddRange(new string[] { "plc-instruction-cookbook", "-ProjectPath", root, "-TaskText", requestBox.Text.Trim() });
                AddWorkflowConfigArg(args, configPath);
            }
            else if (command == "wincc-plugins")
            {
                args.AddRange(new string[] { "wincc-plugins", "-ProjectPath", root, "-TaskText", requestBox.Text.Trim(), "-RefreshCatalog" });
                AddWorkflowConfigArg(args, configPath);
                if (File.Exists(referenceImageBox.Text.Trim()))
                {
                    args.Add("-ReferenceImagePath");
                    args.Add(referenceImageBox.Text.Trim());
                }
            }
            else if (command == "wincc-component-blueprints")
            {
                args.AddRange(new string[] { "wincc-component-blueprints", "-ProjectPath", root, "-TaskText", requestBox.Text.Trim() });
                AddWorkflowConfigArg(args, configPath);
                if (File.Exists(referenceImageBox.Text.Trim()))
                {
                    args.Add("-ReferenceImagePath");
                    args.Add(referenceImageBox.Text.Trim());
                }
            }
            else if (command == "wincc-engineering-scaffold")
            {
                args.AddRange(new string[] { "wincc-engineering-scaffold", "-ProjectPath", root, "-TaskText", requestBox.Text.Trim() });
                AddWorkflowConfigArg(args, configPath);
                if (File.Exists(referenceImageBox.Text.Trim()))
                {
                    args.Add("-ReferenceImagePath");
                    args.Add(referenceImageBox.Text.Trim());
                }
            }
            else if (command == "wincc-openness-implementation")
            {
                args.AddRange(new string[] { "wincc-openness-implementation", "-ProjectPath", root, "-ForCloneOnly" });
                AddWorkflowConfigArg(args, configPath);
            }
            else if (command == "wincc-read-cycle")
            {
                args.AddRange(new string[] { "wincc-read-cycle", "-ProjectPath", root });
                AddWorkflowConfigArg(args, configPath);
            }
            else if (command == "wincc-apply-clone")
            {
                if (SelectedText(safetyModeBox, "克隆编译验证") == "只生成不写入")
                {
                    throw new InvalidOperationException("当前安全策略为“只生成不写入”，请切换到克隆编译验证后再执行。");
                }
                args.AddRange(new string[] { "wincc-apply-clone", "-ProjectPath", root, "-ApplyToClone" });
                string packagePath = Path.Combine(root, "PLC_Code", "wincc", "openness-implementation", "latest");
                if (Directory.Exists(packagePath))
                {
                    args.AddRange(new string[] { "-ImplementationPath", packagePath });
                }
            }
            else if (command == "simulation-package")
            {
                args.AddRange(new string[] { "simulation-package", "-ProjectPath", root, "-TaskText", requestBox.Text.Trim() });
                AddWorkflowConfigArg(args, configPath);
            }
            else if (command == "simulation-replay")
            {
                args.AddRange(new string[] { "simulation-replay", "-ProjectPath", root });
                AddWorkflowConfigArg(args, configPath);
            }
            else if (command == "agent-plan")
            {
                args.AddRange(new string[] { "agent-plan", "-ProjectPath", root, "-TaskText", requestBox.Text.Trim(), "-Workflow", WorkflowId(SelectedText(workflowSelectBox, "读取项目并总结")), "-AgentId", SelectedAgentId() });
                AddWorkflowConfigArg(args, configPath);
                if (File.Exists(referenceImageBox.Text.Trim()))
                {
                    args.Add("-ReferenceImagePath");
                    args.Add(referenceImageBox.Text.Trim());
                }
            }
            else if (command == "agent-queue")
            {
                string latestPlan = Path.Combine(root, "PLC_Code", "agent-plans", "latest-plan.json");
                args.AddRange(new string[] { "agent-queue", "-ProjectPath", root, "-TaskText", requestBox.Text.Trim(), "-PlanPath", latestPlan });
                AddWorkflowConfigArg(args, configPath);
            }
            else if (command == "queue-start-next")
            {
                args.AddRange(new string[] { "queue-stage", "-ProjectPath", root, "-Action", "start-next", "-Note", "Started from PLCDevConsole workbench." });
            }
            else if (command == "queue-run-current")
            {
                args.AddRange(new string[] {
                    "queue-run-current",
                    "-ProjectPath", root,
                    "-RoutingMode", SelectedRoutingMode(),
                    "-Platform", SelectedPlatformId(),
                    "-Model", SelectedAgentModel(),
                    "-Sandbox", SelectedAgentSandbox(),
                    "-TimeoutSeconds", WorkflowTimeoutSeconds().ToString()
                });
                AddWorkflowConfigArg(args, configPath);
                if (agentSearchBox.Checked) { args.Add("-Search"); }
            }
            else if (command == "queue-complete-current")
            {
                args.AddRange(new string[] { "queue-stage", "-ProjectPath", root, "-Action", "complete-current", "-Note", "Marked complete from PLCDevConsole workbench." });
            }
            else if (command == "queue-fail-current")
            {
                args.AddRange(new string[] { "queue-stage", "-ProjectPath", root, "-Action", "fail-current", "-Note", "Marked failed from PLCDevConsole workbench. Inspect logs and evidence before retry." });
            }
            else if (command == "review-package")
            {
                args.AddRange(new string[] { "review-package", "-ProjectPath", root });
                AddWorkflowConfigArg(args, configPath);
            }
            else if (command == "workbench-dashboard")
            {
                args.AddRange(new string[] { "workbench-dashboard", "-ProjectPath", root });
                AddWorkflowConfigArg(args, configPath);
            }
            else if (command == "wincc-visual-package")
            {
                args.AddRange(new string[] { "wincc-visual-package", "-ProjectPath", root, "-TaskText", requestBox.Text.Trim() });
                AddWorkflowConfigArg(args, configPath);
                if (File.Exists(referenceImageBox.Text.Trim()))
                {
                    args.Add("-ReferenceImagePath");
                    args.Add(referenceImageBox.Text.Trim());
                }
            }
            else if (command == "write-cycle")
            {
                string safetyMode = SelectedText(safetyModeBox, "克隆编译验证");
                if (safetyMode == "只生成不写入")
                {
                    throw new InvalidOperationException("当前安全策略为“只生成不写入”，请改为克隆验证后再启动 write-cycle。");
                }
                if (string.IsNullOrWhiteSpace(inputXmlBox.Text) || !File.Exists(inputXmlBox.Text))
                {
                    throw new FileNotFoundException("请先选择或填写要验证的LAD XML文件。", inputXmlBox.Text);
                }
                args.AddRange(new string[] { "write-cycle", "-ProjectPath", root, "-InputXml", inputXmlBox.Text, "-PlcName", PlcName(), "-StepTimeoutSeconds", WorkflowTimeoutSeconds().ToString() });
                AddWorkflowConfigArg(args, configPath);
                if (safetyMode == "克隆编译验证")
                {
                    args.Add("-SkipRelease");
                }
            }
            else
            {
                throw new InvalidOperationException("未知命令：" + command);
            }
            return args;
        }

        private void AddReadCycleSessionArgs(List<string> args)
        {
            if (SelectedText(tiaSessionModeBox, "自动附加") == "显示TIA界面")
            {
                args.Add("-UseUi");
            }
            else
            {
                args.Add("-Attach");
            }
        }

        private static void AddWorkflowConfigArg(List<string> args, string configPath)
        {
            if (!string.IsNullOrWhiteSpace(configPath))
            {
                args.Add("-WorkflowConfigPath");
                args.Add(configPath);
            }
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
                string configPath = SaveWorkflowConfig(false);
                string workflow = Convert.ToString(workflowSelectBox.SelectedItem);
                string referenceImage = referenceImageBox.Text.Trim();
                bool hasReferenceImage = File.Exists(referenceImage);
                string agentContextPath = Path.Combine(root, "PLC_Code", "workbench", "context", "latest", "agent-context.md");
                string projectModelPath = Path.Combine(root, "PLC_Code", "workbench", "context", "latest", "project-model.json");
                string knowledgeBriefPath = Path.Combine(root, "PLC_Code", "knowledge", "packs", "latest", "knowledge-brief.md");
                string knowledgePackPath = Path.Combine(root, "PLC_Code", "knowledge", "packs", "latest", "knowledge-pack.json");
                string winccPluginRouting = "";
                if (workflow.IndexOf("WinCC", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    winccPluginRouting = ResolveWinccPluginRouting(root, configPath, requestBox.Text.Trim(), referenceImage);
                }
                StringBuilder content = new StringBuilder();
                content.AppendLine("# Codex PLC Task");
                content.AppendLine();
                content.AppendLine("Created: " + DateTime.Now.ToString("s"));
                content.AppendLine("Project: `" + root + "`");
                content.AppendLine("Model: `" + Convert.ToString(modelBox.SelectedItem) + "`");
                content.AppendLine("Workflow: `" + workflow + "`");
                content.AppendLine("Workflow config: `" + configPath + "`");
                content.AppendLine();
                content.AppendLine("## Model And API Routing");
                content.AppendLine();
                content.AppendLine("- Code model: `" + Convert.ToString(modelBox.SelectedItem) + "`");
                content.AppendLine("- Language preference: `" + SelectedText(languagePreferenceBox, "LAD优先") + "`");
                content.AppendLine("- TIA session mode: `" + SelectedText(tiaSessionModeBox, "自动附加") + "`");
                content.AppendLine("- Safety mode: `" + SelectedText(safetyModeBox, "克隆编译验证") + "`");
                content.AppendLine("- Step timeout seconds: `" + WorkflowTimeoutSeconds().ToString() + "`");
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
                content.AppendLine("## Project Context And Knowledge");
                content.AppendLine();
                content.AppendLine("- Agent context: `" + (File.Exists(agentContextPath) ? agentContextPath : "missing, run project-model") + "`");
                content.AppendLine("- Project model JSON: `" + (File.Exists(projectModelPath) ? projectModelPath : "missing, run project-model") + "`");
                content.AppendLine("- Knowledge brief: `" + (File.Exists(knowledgeBriefPath) ? knowledgeBriefPath : "missing, run knowledge-pack") + "`");
                content.AppendLine("- Knowledge pack JSON: `" + (File.Exists(knowledgePackPath) ? knowledgePackPath : "missing, run knowledge-pack") + "`");
                content.AppendLine();
                if (File.Exists(agentContextPath))
                {
                    content.AppendLine("### Agent Context Excerpt");
                    content.AppendLine();
                    content.AppendLine("```text");
                    content.AppendLine(Tail(ReadText(agentContextPath), 3500));
                    content.AppendLine("```");
                    content.AppendLine();
                }
                if (File.Exists(knowledgeBriefPath))
                {
                    content.AppendLine("### Knowledge Brief Excerpt");
                    content.AppendLine();
                    content.AppendLine("```text");
                    content.AppendLine(Tail(ReadText(knowledgeBriefPath), 3500));
                    content.AppendLine("```");
                    content.AppendLine();
                }
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
                    content.AppendLine("## Required Plugin Routing");
                    content.AppendLine();
                    content.AppendLine("Use the ready adapters in this routing plan. For `codex-imagegen`, explicitly invoke `$imagegen`; for engineering adapters, preserve backup/clone-first behavior. Do not run an unreviewed downloaded executable.");
                    content.AppendLine();
                    content.AppendLine("```json");
                    content.AppendLine(winccPluginRouting);
                    content.AppendLine("```");
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
                content.AppendLine("1. Run `project-model` and `knowledge-pack` if the context or sources are stale.");
                content.AppendLine("2. Run `read-cycle -Attach -SkipExport` if the project structure is stale.");
                content.AppendLine("3. Edit exported LAD XML, LAD JSON specs, SCL sources, or DB sources.");
                content.AppendLine("4. For WinCC visual tasks, first produce a screen map and component/tag contract, then generate or update screens through Openness/SiVArc where available.");
                content.AppendLine("5. Use `write-cycle` on a cloned project before applying PLC-side generated LAD XML to the real project.");
                File.WriteAllText(path, content.ToString(), Encoding.UTF8);
                chatBox.AppendText(Environment.NewLine + "用户任务：" + requestBox.Text.Trim() + Environment.NewLine);
                chatBox.AppendText("模型：" + Convert.ToString(modelBox.SelectedItem) + "    工作流：" + workflow + "    语言：" + SelectedText(languagePreferenceBox, "LAD优先") + "    安全：" + SelectedText(safetyModeBox, "克隆编译验证") + Environment.NewLine);
                chatBox.AppendText("配置：" + configPath + Environment.NewLine);
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

        private string ResolveWinccPluginRouting(string root, string configPath, string taskText, string referenceImage)
        {
            string routePath = Path.Combine(root, "PLC_Code", "wincc", "plugin-routing.json");
            try
            {
                List<string> args = new List<string>();
                args.Add("wincc-plugins");
                args.Add("-ProjectPath");
                args.Add(root);
                AddWorkflowConfigArg(args, configPath);
                if (!string.IsNullOrWhiteSpace(taskText))
                {
                    args.Add("-TaskText");
                    args.Add(taskText);
                }
                if (File.Exists(referenceImage))
                {
                    args.Add("-ReferenceImagePath");
                    args.Add(referenceImage);
                }

                ProcessStartInfo start = new ProcessStartInfo();
                start.FileName = "powershell.exe";
                start.Arguments = "-NoProfile -ExecutionPolicy Bypass -File " + Quote(invokeScript) + " " + JoinArgs(args);
                start.WorkingDirectory = root;
                start.UseShellExecute = false;
                start.CreateNoWindow = true;

                using (Process process = Process.Start(start))
                {
                    if (!process.WaitForExit(15000))
                    {
                        process.Kill();
                        return "{\"status\":\"timeout\",\"message\":\"WinCC plugin routing exceeded 15 seconds; use the last cached route or run the scanner from the toolbar.\"}";
                    }
                    if (process.ExitCode != 0)
                    {
                        return "{\"status\":\"error\",\"message\":\"WinCC plugin routing failed; run the toolbar scanner to inspect its log.\"}";
                    }
                    if (File.Exists(routePath))
                    {
                        return ReadText(routePath);
                    }
                    return "{\"status\":\"missing-output\"}";
                }
            }
            catch (Exception ex)
            {
                return "{\"status\":\"error\",\"message\":" + JsonString(ex.Message) + "}";
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

        private sealed class LadConditionEntry
        {
            public string Kind;
            public string Left;
            public string Right;
            public string SourceType;

            public override string ToString()
            {
                string text = Kind + "  |  " + Left;
                if (!string.IsNullOrWhiteSpace(Right)) { text += "  |  " + Right; }
                if (!string.IsNullOrWhiteSpace(SourceType)) { text += "  |  " + SourceType; }
                return text;
            }
        }

        private sealed class LadActionEntry
        {
            public string Kind;
            public string Target;
            public string Instance;
            public string Pt;

            public override string ToString()
            {
                string text = Kind + "  |  " + Target;
                if (!string.IsNullOrWhiteSpace(Instance)) { text += "  |  " + Instance; }
                if (!string.IsNullOrWhiteSpace(Pt)) { text += "  |  " + Pt; }
                return text;
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
