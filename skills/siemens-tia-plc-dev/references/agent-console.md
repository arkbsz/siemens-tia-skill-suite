# 内置多平台 Agent 控制台

`PLCDevConsole.exe` 通过统一适配器调用本机已经安装并完成授权的 AI 编程平台。应用内置的是平台适配、Siemens Agent、工作流和 skill，不是各平台的商业模型、账号或授权文件。

## 支持的平台

- Codex：`codex exec --json`，支持连续会话、图片附件和原生联网检索。
- Claude Code：`claude -p --output-format stream-json`，适合 SCL、诊断、DB 契约和只读审查。
- Trae Agent：`trae-cli run`，可配置 provider 与 model；当前按无状态任务运行并保存 trajectory。
- Qoder：`qodercli -p ... -f stream-json`，支持模型、工作目录、权限模式和会话 ID。

平台定义保存在 `agents/ai-platforms.json`，任务路由保存在 `agents/siemens-workflow-routes.json`。`scripts/invoke-ai-platform-agent.ps1` 把各平台输出转换成统一 JSONL 事件，窗口只处理 `platform.selected`、`thread.started` 和 `item.completed` 等稳定事件。

## 自动与手动路由

自动路由根据工作流读取平台优先级，并跳过本机未安装的平台。例如 SCL、诊断和审查优先 Claude Code，LAD、WinCC 和 Openness 优先 Codex；当前机器只有 Codex 时会自动落到 Codex。

手动路由严格使用用户指定的平台。指定平台未安装或命令不可解析时必须失败并显示安装提示，不得静默切换到其他平台。

平台或路由模式改变后清空旧会话 ID，防止把 Codex 的 thread id 交给 Claude/Qoder，或把其他平台的 session id 交给 Codex。Trae Agent 当前不恢复会话。

## 内置 Agent

Agent 配置保存在 `agents/siemens-agent-profiles.json`：

- 自动路由 Agent
- PLC LAD 工程师
- PLC SCL 工程师
- DB 与变量架构师
- WinCC 画面工程师
- Openness 自动化工程师
- 编译诊断 Agent
- 只读审查 Agent

用户选择“自动路由 Agent”时，工作流目录决定实际 Agent；手动选择具体 Agent 时，具体 Agent 指令优先，但仍叠加当前工作流的安全约束和 skill 路由。

## 文件与审计

- 上传文件先复制到 `PLC_Code\agent-attachments`，再通过本次请求的附件清单传给 Agent。
- 每次请求、附件清单、统一 JSONL、stderr 和会话信息保存在 `PLC_Code\agent-sessions`。
- Codex 可把图片作为原生 `-i` 附件；其他平台至少能读取项目内附件路径。是否支持原生多模态由对应 CLI 与模型决定。
- Trae trajectory 保存在 `PLC_Code\agent-sessions\trae-trajectories`。

## 安全边界

`read-only` 用于审查，`workspace-write` 用于正常 PLC-as-code 工作，`danger-full-access` 仅用于用户明确确认的操作。平台切换不会绕过生产工程保护：PLC/HMI 改动仍应先备份，在克隆工程导入、编译和回读，最后单独确认主工程写入。

不要把 API Key 明文写进 `ai-workflow.json`。Codex、Claude Code、Trae 和 Qoder 的账号、Token、API Key 与供应商配置由各自 CLI 或环境变量管理。

## 命令行调用

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" agent-chat -ProjectPath "D:\path\to\project" -PromptFile "D:\path\to\message.txt" -AgentId plc-lad -Workflow plc-lad -RoutingMode auto -Platform auto -Sandbox workspace-write -Search
```

检测本机平台：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" probe-ai-platforms
```
