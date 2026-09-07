# 西门子 TIA 自动化开发技能套件

版本：`1.0.0`  
发布日期：`2026-08-10`

面向 Siemens TIA Portal 的多平台技能套件，兼容 Codex、Claude Code 与 Cursor，支持 TIA Portal `V16-V21`，主打 PLC-as-code 与 HMI/WinCC 自动化工作流。适合做项目备份、块导出、LAD/XML 编辑、WinCC 画面与标签自动化、源码导入、编译验证，以及本地 Openness / REST 桥接自动化。

## 项目简介

这套仓库把西门子 PLC 与 WinCC 开发里常见、重复、容易出错的流程打包成可复用技能，目标是让博图工程开发更接近普通代码开发体验。它不是替代 TIA Portal，而是把备份、读取、生成、导入、编译验证、回读比对这些步骤标准化，让 AI 助手可以围绕工程文件、导出源码和 Openness 接口协同工作。

## 多平台支持

- Codex：使用 `skills/` 下的技能目录
- Claude Code：使用仓库根目录的 `CLAUDE.md`
- Cursor：使用仓库根目录的 `.cursorrules`

三者共用同一套 TIA / Openness / LAD / SCL 资源。

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
- 本地窗口版 `PLCDevConsole.exe`：项目结构、runs/log、常用工作流按钮和 AI 任务草稿区
- 本地 Openness 自动化和 REST 桥接
- `V16-V21` 版本探测、项目后缀识别、程序集路径路由
- 编译验证与回读比对
- 一键 `read-cycle` 读取工程，一键 `write-cycle` 在克隆工程中验证生成的 LAD XML 并准备发布包
- 可复用的工业项目示例与命名规范
- 官方文档优先、社区案例补充、结合当前项目结构的知识检索路线

## WinCC 自动开发

这个套件新增了 WinCC HMI 自动化内容，适合做：

- HMI 画面、Faceplate、报警、文本和导航结构生成
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
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install-skills.ps1
```

默认安装位置：

- `%USERPROFILE%\.codex\skills`

## 本地窗口版开发控制台

安装后可以一键构建并打开原生 Windows 窗口：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" console -ProjectPath "D:\path\to\project"
```

控制台包含：

- 左侧项目结构：查看 `.ap16-.ap21` 工程、导出 XML、SCL、DB、UDT、报告和日志。
- 中间工作流与日志：运行 `doctor`、快速读取、完整导出、列块、`write-cycle` 克隆验证。
- 右侧 AI 对话区：生成带当前项目结构、最近 runs 和块列表的 Codex 任务草稿，保存到 `PLC_Code\ai-prompts`。

`console` 和 `console-exe` 默认启动窗口版。旧的浏览器控制台保留为备用入口 `console-web`，不再作为默认方式。当前 AI 区定位是“Codex 任务草稿生成器”，不会在后台偷偷调用云端模型。真正的程序生成、审查、LAD 修改和导入验证仍建议回到 Codex 主对话执行。

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
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1 write-cycle -ProjectPath "D:\path\to\project" -InputXml "D:\path\to\generated.xml" -PlcName "PLC_1"
```

`write-cycle` 运行时间通常比读取长，因为它会复制克隆工程并调用 TIA 编译。运行中可查看 `PLC_Code\runs\write-cycle-*\current-step.json` 和 `logs` 下的临时输出文件；需要限制单步等待时间时可加 `-StepTimeoutSeconds 300`。

## 目标机器要求

- 已安装 TIA Portal `V16`、`V17`、`V18`、`V19`、`V20` 或 `V21`
- 本机 TIA 安装目录下存在 Openness PublicAPI
- 已安装 .NET Framework 4.8 或兼容的本地构建环境
- 需要写入工程时，当前 Windows 用户应加入 `Siemens TIA Openness` 用户组，并完成重新登录使权限生效
- 首次使用 Openness 自动化时，如果遇到安全超时，请使用 `-UseUi` 运行一次并接受 Siemens 信任提示

## 仓库结构

- `skills/`：可安装的 Codex 技能目录
- `install-skills.ps1`：本地一键安装脚本
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
- 社区案例、开源工具和工程实践文章
- 当前项目导出的 LAD XML、摘要、SCL 源码和 DB 结构

## 使用建议

- 导入主工程前，优先在备份或克隆工程上验证。
- 尽量把导出的 XML 和 SCL 作为可审查、可回溯的源码依据。
- 本仓库定位为可发行的技能套件，不是 Siemens 运行库或工程二进制文件合集。
