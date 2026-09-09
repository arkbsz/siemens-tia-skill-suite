# AI 工作流配置

原生控制台为每个项目保存一份配置：

```text
PLC_Code\config\ai-workflow.json
```

快速栏可设置路由模式、AI 平台、Agent、模型、工作流、PLC 语言、TIA 会话和安全策略。工具菜单中的高级面板还可设置四个平台命令路径、Trae provider、API 环境变量、图像工作流、WinCC 插件和界面字体。模型下拉框允许直接输入平台支持的自定义模型 ID。

## 平台配置

```json
{
  "platform": {
    "routingMode": "auto",
    "selected": "auto",
    "sessionPlatform": "codex",
    "codexCommand": "",
    "claudeCommand": "",
    "traeCommand": "",
    "qoderCommand": "",
    "traeProvider": ""
  }
}
```

- `routingMode=auto`：按 `siemens-workflow-routes.json` 的优先级选择第一个可用平台。
- `routingMode=manual`：只使用 `selected` 指定的平台；不可用时明确失败。
- `sessionPlatform`：记录当前会话属于哪个平台，平台改变时清除不兼容 session。
- 四个 `*Command`：留空时从 PATH、平台环境变量和本机默认安装目录自动检测；也可填写完整可执行文件路径。
- `traeProvider`：传给 Trae Agent 的 `--provider`，留空时使用 Trae 自己的配置。

## 运行映射

- `routing.codeModel` 为 `继承平台/工作流默认` 时，适配器使用当前工作流对该平台的推荐模型；自定义值原样传给平台 CLI。
- `routing.workflow` 决定平台优先级、Agent、skill 和任务专用指令。
- `routing.workflowAuto=true` 表示界面显示的具体工作流只是最近一次推断结果，用户继续修改任务文字时仍会重新推断；手动选择具体工作流后变为 `false`。
- `routing.languagePreference` 决定 read-cycle 的 LAD、FBD、SCL 导出优先级。
- `agent.profile` 为 `auto` 时由工作流选择 Agent，具体 Agent 则覆盖工作流默认 Agent。
- `agent.search` 对 Codex 启用原生 `--search`；对其他平台写入知识检索要求，由平台自身工具能力执行。
- `agent.sandbox` 映射到各平台的只读、工作区写入或显式危险权限。
- `agent.threadId` 与 `platform.sessionPlatform` 一起用于恢复兼容会话。
- `tia.sessionMode=显示TIA界面` 让 read-cycle 使用 `-UseUi`；其他模式使用 `-Attach`。
- `tia.stepTimeoutSeconds` 控制 write-cycle 子步骤超时。
- `safety.safetyMode=只生成不写入` 阻止 write-cycle。
- `safety.allowProductionWrite` 固定为 `false`，主工程发布仍是独立人工确认动作。

`read-cycle` 和 `write-cycle` 都接受 `-WorkflowConfigPath`，并在运行报告旁保存配置快照。Agent 调用也记录实际的 `platform.selected` 事件，因此可以追溯最终使用的平台、模型、工作流和 Agent。

WinCC 插件路由读取 `wincc` 与 `image` 配置。`wincc-plugins` 刷新插件能力并写入 `PLC_Code\wincc\plugin-routing.json`，WinCC Agent 再结合参考图、PLC/HMI 标签契约和目标 WinCC 类型选择 Openness、SiVArc、MCP、GraphQL、脚本或原生控件路线。

`knowledge-pack` 会读取同一份配置，并生成 `PLC_Code\knowledge\packs\latest\knowledge-brief.md/json`，把 Siemens 官方文档、官方 GitHub 示例、当前项目结构和需审查社区路线整理为 Agent 可读检索包。启用联网时只刷新元数据和源锚点；社区二进制仍不会自动执行。

`capability-map` 会读取同一份配置和当前 `PLC_Code` 产物，并生成 `PLC_Code\workbench\capabilities\latest\capability-map.md/json`。它用于判断本地工作台距离“替代 TIA 原生编辑器”的实际覆盖度：每项能力必须有 UI 入口、脚本命令、产物、验证门槛和剩余 TIA 依赖。

`agent-pipeline` 会读取同一份配置，并把配置快照传给项目模型、知识包、能力矩阵、PLC 指令计划、WinCC 插件路由、WinCC 视觉工程包、Agent 计划、Agent 队列和工作台总览。它适合用户在本地窗口提交一个较大的自动化开发需求后，先得到可审查的开发骨架、任务队列和验证证据，而不是直接写入生产工程。

可选 WinCC/预览字段：

- `wincc.tiaMcpPath`：经过源码和版本审查的 TIA MCP 可执行文件路径。
- `wincc.tiaV20UnifiedMcpPath`：经过源码和许可证审查的 V20 Unified MCP 路径，用于 V20/V21 实验性 Unified 工程路线。
- `wincc.tiaOpennessManagerPath`：经过源码和许可证审查的 TIA Openness Manager 路径，默认只用于批量导入/导出、审查和克隆工程验证路线。
- `wincc.showScriptsPath`：Unified ShowScripts Add-In 或导出工具路径。
- `wincc.runtimeMcpPath`：WinCC Unified Runtime GraphQL/MCP 服务入口。
- `wincc.graphqlUrl`：可信工程网络内的 Unified GraphQL endpoint。
- `wincc.tiaViewerPath`：只读 TIA Viewer / ImportExport 类适配器路径，用于 SimaticML、SCL、DB、UDT、LAD/FBD、GRAPH 等导出对象的离线预览；不得用作未经验证的写入通道。

配置文件只保存 API Key 的环境变量名称，不保存密钥值。各平台登录信息仍由对应 CLI 管理。
