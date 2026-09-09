# 西门子 TIA 自动化开发技能套件

版本：`1.0.0`  
发布日期：`2026-08-10`

面向 Siemens TIA Portal 的多平台技能套件，支持 Codex、Claude Code、Trae Agent、Qoder、Cursor 等开发入口，兼容 TIA Portal `V16-V21`，主打 PLC-as-code 与 HMI/WinCC 自动化工作流。适合做项目备份、块导出、LAD/XML 编辑、WinCC 画面与标签自动化、源码导入、编译验证，以及本地 Openness / REST 桥接自动化。

## 项目简介

这套仓库把西门子 PLC 与 WinCC 开发里常见、重复、容易出错的流程打包成可复用技能，目标是让博图工程开发更接近普通代码开发体验。它不是替代 TIA Portal，而是把备份、读取、生成、导入、编译验证、回读比对这些步骤标准化，让 AI 助手可以围绕工程文件、导出源码和 Openness 接口协同工作。

## 多平台支持

- 桌面应用 Agent：统一适配 Codex、Claude Code、Trae Agent 和 Qoder CLI，按 PLC 任务自动选择，也可手动指定平台、模型、Agent 和工作流。
- Codex：使用 `skills/` 下的技能目录和原生连续会话、图片附件、联网检索。
- Claude Code：既可读取仓库根目录的 `CLAUDE.md`，也可作为桌面应用执行平台。
- Trae Agent：作为可配置 provider/model 的任务执行平台，保存 trajectory 供审计。
- Qoder：使用 stream-json 和 session-id 接入桌面应用，并兼容 `.agents/skills` 结构。
- Cursor：使用仓库根目录的 `.cursorrules` 共享项目约束。

各平台共用同一套 TIA / Openness / LAD / SCL / WinCC 资源和安全规则。

## 内置技能

- `siemens-tia-plc-dev`：通用西门子 PLC 开发入口，负责项目备份、版本路由、LAD/SCL/XML 工作流、导入验证和发布包准备。
- `tia-portal-v17`：本机 TIA Portal `V16-V21` Openness 桥接层，保留旧名称以兼容历史调用，同时支持 `.ap16` 到 `.ap21` 项目识别。
- `codex-tia-client`：面向 Codex 的主入口，用于替代独立 AI 助手，完成备份、导出、编写、导入和编译闭环。
- `siemens-wincc-hmi-dev`：WinCC HMI 自动化入口，用于画面、变量、报警、Faceplate、导航和运行时通信工作流。

## 功能

- 项目备份优先，先复制再改
- 导出和导入 FC、FB、DB、LAD XML、SCL
- LAD 梯形图模板化生成与网络批量写入
- WinCC 画面、变量、报警、Faceplate、导航、版式与运行时联动自动化
- WinCC 参考图/文字描述驱动设计：可选择文生图、图生图/参考图、组件匹配、Faceplate、SiVArc 或自定义组件路线
- 本地窗口版 `PLCDevConsole.exe`：IDE 风格顶部菜单、精简项目工具条、右侧滚动界面、左侧可拖动项目树、中心日志/预览/对话页面、底部 AI 工作流任务区
- 内置多平台 Agent 对话：在窗口中直接选择自动/手动路由、Codex/Claude Code/Trae/Qoder、PLC LAD/SCL/DB/WinCC/Openness/诊断/审查 Agent、工作流和自定义模型，无需另开 AI 窗口
- 本地工作台任务编排：一键生成 `PLC_Code\agent-plans\latest-plan.md/json`，把任务拆成读取、知识检索、DB/块契约、LAD/SCL/高级指令、WinCC 组件拆分、验证、安全评估和发布包阶段
- 本地工作台执行队列：一键生成 `PLC_Code\agent-queues\latest\queue.md/json` 和阶段 prompt，把计划拆成可逐项执行、记录日志和保存验证证据的 Agent 队列
- 项目对象模型：一键生成 `PLC_Code\workbench\context\latest\project-model.json`、`agent-context.md` 和 `file-index.csv`，把 TIA 版本、程序块、DB、导出文件、WinCC 包、队列和风险整理成 Agent 可读上下文
- 任务知识检索包：一键生成 `PLC_Code\knowledge\packs\latest\knowledge-brief.md/json`，优先绑定 Siemens 官方文档、官方 GitHub 示例、当前项目证据和需审查社区路线
- 工作台能力矩阵：一键生成 `PLC_Code\workbench\capabilities\latest\capability-map.md/json`，明确本地窗口对项目读取、LAD 读写、SCL/DB、WinCC、Agent 队列、仿真验证和发布审查的覆盖度与缺口
- PLC 指令库：一键生成 `PLC_Code\plc\instruction-cookbook\latest`，把位逻辑、比较、定时、计数、运动、驱动通信、PID、诊断、数组、配方、数学和转换指令路由到 LAD JSON、通用 `CALL`、SCL、donor LAD 或工艺对象配置
- WinCC 组件蓝图：一键生成 `PLC_Code\wincc\component-blueprints\latest`，沉淀画面外壳、报警条、工位卡、电机/气缸/驱动面板、趋势、参数、诊断表、SiVArc 规则和 CWC 候选清单
- WinCC 工程脚手架：一键生成 `PLC_Code\wincc\engineering-scaffold\latest`，输出前置检查、HMI 变量导入表、报警导入表、Faceplate 制作清单、SiVArc 检查表、CWC 审查、运行时冒烟和克隆验证计划
- 仿真与运行验证包：一键生成 `PLC_Code\simulation\latest`，把静态校验、克隆编译、回读比对、PLCSIM Advanced 虚拟控制器、WinCC Unified GraphQL 冒烟和发布门槛整理成可执行场景
- 自动开发流水线：一键执行 `agent-pipeline`，按任务自动判断 PLC/WinCC 范围，生成知识包、能力矩阵、PLC 指令库、PLC 指令方案、WinCC 视觉工程包、WinCC 组件蓝图、Agent 计划、执行队列和工作台验证总览
- 队列状态控制：支持开始下一阶段、完成当前阶段、标记失败/阻塞和重置队列，并自动生成当前阶段 prompt 与建议命令
- 工作台审查包：一键生成 `PLC_Code\review-packages\latest`，汇总计划、队列、PLC 改动包、WinCC 工程包、文件哈希、git diff 和导入就绪检查
- 离线图形预览适配：可配置 TIA Viewer / ImportExport 类工具路径，用于后续把 SimaticML、LAD/FBD、GRAPH、SCL、DB、UDT 导出文件渲染到工作台预览
- 本地编辑闭环：工作台可直接编辑导出的 XML/SCL/DB/Markdown/JSON 文件，保存前自动备份到 `PLC_Code\file-backups`，并支持一键生成 LAD XML 可读预览。
- PLC 改动包：一键生成 `PLC_Code\changes\latest-plc-change-package`，包含块/DB契约、命名映射、LAD JSON 模板、SCL/DB 源码目录、导入清单、验证计划和安全风险评估。
- 针对性自动路由：LAD、WinCC、Openness、SCL、DB 契约、诊断和审查使用独立的 skill 组合、平台优先级与任务指令
- 文件上传：图片、PDF、文档、源码、XML 和日志自动复制到项目工作区并随当前消息交给 Agent
- 本地 Openness 自动化和 REST 桥接
- `V16-V21` 版本探测、项目后缀识别、程序集路径路由
- 编译验证与回读比对
- 一键 `read-cycle` 读取工程，一键 `write-cycle` 在克隆工程中验证生成的 LAD XML 并准备发布包
- 可复用的工业项目示例与命名规范
- 官方文档优先、社区案例补充、结合当前项目结构的知识检索路线

## WinCC 自动开发

这个套件新增了 WinCC HMI 自动化内容，适合做：

- HMI 画面、Faceplate、报警、文本和导航结构生成
- 用户上传参考图或输入文字描述后，按任务自动推荐代码模型、图像模型、API 提供方、质量、尺寸和组件策略
- 根据参考图提取布局、配色、字体层级、状态颜色和组件结构，再映射为 WinCC 标准控件、Faceplate、SiVArc 规则或自定义组件
- 自动生成 WinCC 视觉工程包，包含参考图分析、组件选择矩阵、插件调用计划、CWC/Faceplate 包装建议和可审查工程任务 JSON
- 自动生成 WinCC 工程脚手架，进一步把设计包转换成 HMI tag/alarm CSV、Faceplate/SiVArc/CWC 制作清单、工程前置检查和克隆验证计划
- PLC 数据块与 HMI 变量映射
- 工业风格画面规范：总览、工位、手动、报警、趋势、参数、维护分层
- WinCC Unified 运行时读写、订阅和诊断联动
- SiVArc 规则驱动的界面生成和批量配置

## 不随仓库分发的内容

- `Siemens.Engineering.dll`
- `Siemens.Engineering.Hmi.dll`
- `Siemens.Engineering.WinCC.dll`
- `Siemens.Engineering.WinCCUnified.dll`
- `Siemens.Engineering.Sivarc.dll`
- prebuilt `TiaPlcTool.exe`
- session caches and Python bytecode

这些 Siemens 二进制文件、预编译工具和临时缓存不会随仓库分发。这样可以避免携带受限运行库，并让工具在目标机器上绑定本机已安装的 TIA Portal `V16-V21` PublicAPI，必要时再本地重新生成辅助程序。

## 安装方式

1. 下载或解压本仓库。
2. 在仓库根目录运行 `install-skills.ps1`。
3. 如果 Codex 已经打开，安装后重启 Codex，让新技能重新加载。

## 一键部署

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\setup-siemens-tia-suite.ps1 -ProjectPath "D:\path\to\project"
```

该脚本会备份并安装全部 skill，检测 Codex、Claude Code、Trae Agent 和 Qoder，至少需要一个可用平台；没有任何平台且允许安装依赖时，默认补齐官方 `@openai/codex` CLI。只有明确添加 `-InstallClaudeCode` 或 `-InstallQoder` 时才会全局安装对应第三方 CLI。随后脚本写入 Agent 运行配置、编译并启动本地窗口。只安装 skill 时仍可使用 `install-skills.ps1`。

## 单文件保护版

需要向最终用户发行而不直接提供源码目录时，可生成自包含的 `SiemensTIAAgent.exe`：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build-protected-exe.ps1
```

该 EXE 内嵌加密后的 PLC/WinCC skill、Agent 配置、工作流和交互窗口，运行时使用当前用户受限的临时目录，窗口关闭后自动清理。详细保护范围、代码签名和安全边界见 `PROTECTED_RELEASE.md`。

默认安装位置：

- `%USERPROFILE%\.codex\skills`

## 本地窗口版开发控制台

安装后可以一键构建并打开原生 Windows 窗口：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" console -ProjectPath "D:\path\to\project"
```

控制台包含：

- 顶部项目栏：精简为单行工具条，保留项目路径、读取当前 TIA、浏览打开、加载项目和版本徽标；打开项目文件夹、用 TIA/默认程序打开等低频操作移入菜单。
- 顶部菜单栏：提供 `文件、编辑、视图、导航、代码、重构、运行、工具、Git、窗口、帮助` 菜单，常用命令和设置项从菜单下拉进入。
- 右侧滚动界面：主内容放入可滚动画布，窗口高度不足时右侧出现纵向滚动条，并支持鼠标滚轮上下滚动。
- 左侧项目结构：可拖动宽度，查看 `.ap16-.ap21` 工程、导出 XML、SCL、DB、UDT、报告和日志。
- 中间主界面：通过 Tab 切换 AI 对话、日志输出、文件预览和 runs 列表，并可上下拉伸工作区。
- 设置下拉面板：在 `工具 > AI平台 / Agent / 工作流 / WinCC 设置` 中配置自动/手动路由、平台、四个平台命令覆盖、模型、工作流、API、图像模型、组件策略、字体和字号；面板支持滚动。
- 底部 AI 交互区：使用两行响应式快速配置和独立附件栏，可选择路由模式、平台、内置 Agent、自定义模型和工作流；发送、停止、新会话和任务草稿采用紧凑操作区，避免控件遮挡并为任务输入保留更多空间。
- Agent 会话：每次请求、附件清单、JSONL 事件和错误日志保存在 `PLC_Code\agent-sessions`，附件副本保存在 `PLC_Code\agent-attachments`。
- WinCC 视觉页：上传参考图后在中心 `参考图` Tab 中预览，任务草稿会自动写入文生图/图生图提示词、组件匹配计划和 WinCC 原生实现步骤。
- Agent 编排页：中心新增 `任务编排` Tab，可直接预览由工作台生成的阶段计划、工具选择、产物路径、验证门槛和安全边界。
- 项目模型页：中心新增 `项目模型` Tab，可查看最新 Agent 上下文包和机器可读项目索引，让后续 Agent 不必从零理解工程。
- 知识库页：中心新增 `知识库` Tab，可查看官方优先检索包、社区插件候选、检索关键词和当前项目上下文绑定。
- 能力矩阵页：中心新增 `能力矩阵` Tab，可查看本地窗口替代 TIA 原生编辑器的实际覆盖范围、验证状态、剩余 TIA 依赖和下一步增强方向。
- 自动开发流水线：`自动流水线` 按钮会根据任务文本和参考图自动串联 PLC 指令计划、WinCC 插件路由、WinCC 视觉包、Agent 编排、执行队列和总览面板，形成第一轮可审查开发骨架。
- Agent 执行队列：`执行队列` 按钮会把最新计划转成阶段 prompt、建议命令、日志目录和证据目录；缺少计划时会自动先生成计划。
- 队列阶段控制：运行菜单和设置面板可开始下一阶段、完成当前阶段或标记失败，中心任务编排页会显示当前阶段 prompt。
- 工作台审查包：`审查包` 按钮用于把当前 PLC/WinCC/Agent 产物整理成 PR 式审查材料，适合导入、编译或发布前检查。
- 离线预览配置：高级设置里的 `离线预览` 可填入经过审查的 TIA Viewer / ImportExport 适配器路径，目前按只读预览能力记录到插件路由。
- 文件编辑：项目树选择文件后可在 `文件预览` 中切换 `编辑预览` 并保存；保存前自动生成项目内备份。`LAD预览` 按钮会把当前 LAD XML 转为可读 Markdown 摘要。
- PLC 改动包：`PLC改动包` 按钮为当前任务创建结构化编辑工作区，让 LAD、SCL、DB、导入和验证资料集中管理。
- 视觉设置：使用柔和工业渐变、卡片式区域、圆角按钮，并读取 Windows 本机字体库供界面文字配置。

`console` 和 `console-exe` 默认启动窗口版。旧的浏览器控制台保留为备用入口 `console-web`。窗口通过本机已安装并授权的 Codex、Claude Code、Trae Agent 或 Qoder 调用 Agent，不在项目配置中保存 API 密钥；生产工程写入仍必须经过备份、克隆验证和明确确认。

## 推荐使用顺序

1. 先运行 `doctor` 检查本机 Openness 会话是否就绪
2. 首次重装或修复 Openness 后，先用 `read-cycle -UseUi` 完成 Siemens Openness 信任握手
3. 就绪后先用 `read-cycle -Attach` 读取工程、导出块、生成 LAD 摘要和目录
4. 生成或修改 LAD XML 后，用 `write-cycle` 在克隆工程中导入、编译、回读并准备发布包
5. 最后人工确认验证报告后，再使用 `apply-release` 写入主工程
6. 如果会话未就绪，先走离线 XML / SCL / 模板化开发路线，不要反复卡在 live Openness

示例：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1 doctor -ProjectPath "D:\path\to\project"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1 read-cycle -ProjectPath "D:\path\to\project" -UseUi
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1 project-model -ProjectPath "D:\path\to\project" -TaskText "生成项目对象模型和Agent上下文"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1 knowledge-pack -ProjectPath "D:\path\to\project" -TaskText "检索 PLC/WinCC 官方资料和社区案例" -RefreshOnline
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1 capability-map -ProjectPath "D:\path\to\project" -TaskText "评估本地工作台替代 TIA 编辑器的覆盖度"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1 plc-instruction-cookbook -ProjectPath "D:\path\to\project" -TaskText "生成通用PLC指令开发库"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1 wincc-component-blueprints -ProjectPath "D:\path\to\project" -TaskText "生成WinCC可复用组件蓝图"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1 wincc-engineering-scaffold -ProjectPath "D:\path\to\project" -TaskText "生成WinCC工程脚手架"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1 simulation-package -ProjectPath "D:\path\to\project" -TaskText "生成仿真与运行验证包"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1 agent-pipeline -ProjectPath "D:\path\to\project" -TaskText "规划 LAD、DB、WinCC 画面和验证队列" -RefreshWinccCatalog
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1 plc-change-package -ProjectPath "D:\path\to\project" -TaskText "Add motor interlock logic" -Workflow plc-lad
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1 write-cycle -ProjectPath "D:\path\to\project" -InputXml "D:\path\to\generated.xml" -PlcName "PLC_1"
```

`write-cycle` 运行时间通常比读取长，因为它会复制克隆工程并调用 TIA 编译。运行中可查看 `PLC_Code\runs\write-cycle-*\current-step.json` 和 `logs` 下的临时输出文件；需要限制单步等待时间时可加 `-StepTimeoutSeconds 300`。

## 目标机器要求

- 至少安装并授权一个 Agent CLI：Codex、Claude Code、Trae Agent 或 Qoder
- 已安装 TIA Portal `V16`、`V17`、`V18`、`V19`、`V20` 或 `V21`
- 本机 TIA 安装目录下存在 Openness PublicAPI
- 已安装 .NET Framework 4.8 或兼容的本地构建环境
- 需要写入工程时，当前 Windows 用户应加入 `Siemens TIA Openness` 用户组，并完成重新登录使权限生效
- 首次使用 Openness 自动化时，如果遇到安全超时，请使用 `-UseUi` 运行一次并接受 Siemens 信任提示

## 仓库结构

- `skills/`：可安装的 Codex 技能目录
- `install-skills.ps1`：本地一键安装脚本
- `setup-siemens-tia-suite.ps1`：skill、多平台 Agent、依赖和本地窗口的一键配置入口
- `dependencies.json`：必需和可选依赖清单
- `build-protected-exe.ps1`：生成加密、自校验、自包含的单文件 Windows 应用
- `PROTECTED_RELEASE.md`：保护版构建、分发和安全边界说明
- `release-manifest.json`：发布元数据和验证记录
- `LICENSE`：仓库的 MIT 开源许可证

## 验证依据

- 已使用本套技能完成离线 `备份 -> 源码导入 -> 块导入 -> 编译 -> LAD 导出和回读` 闭环。
- 已验证的梯形图流程包括定时器相关 LAD 修改、网络批量重写，以及辅助 DB 源码的配套导入。
- 最近的工业化和仿真增强已验证 `DB_7SimulationPanel`、`FC7_SimulationIO`，以及绑定到 DB `TIME` 变量的 `TON.PT`。

## 知识来源

- Siemens 官方指令族文档：`docs.tia.siemens.cloud`
- Siemens 支持手册与 Openness 文档：`support.industry.siemens.com`
- Siemens 官方 GitHub Openness 示例代码
- Siemens SiVArc Openness、WinCC Unified GraphQL、WinCC Unified CWC 官方资料
- 社区案例、开源工具和工程实践文章
- 当前项目导出的 LAD XML、摘要、SCL 源码和 DB 结构

## 使用建议

- 导入主工程前，优先在备份或克隆工程上验证。
- 尽量把导出的 XML 和 SCL 作为可审查、可回溯的源码依据。
- 本仓库定位为可发行的技能套件，不是 Siemens 运行库或工程二进制文件合集。
