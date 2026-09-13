# 单文件保护版

`SiemensTIAAgent.exe` 是面向最终用户的单文件发行形式。交互窗口、PLC/WinCC skill、Agent 配置和工作流脚本都存放在 EXE 内部的加密容器中，发行时不需要附带源码目录。

## 构建

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build-protected-exe.ps1
```

输出文件：

```text
protected-release\SiemensTIAAgent.exe
```

最近验证构建：

```text
时间：2026-09-13 15:44 +08:00
版本：1.0.6
文件：protected-release\SiemensTIAAgent.exe
SHA256：6644F74D2B851284C3637C9DE7B59B72988ADC1600994096DA44C738735E464D
载荷文件数：230
自检：Passed

本轮还通过了原生工作台 `doctor` 任务持久化烟囱测试，以及不依赖联网和真实 AI 账号的 Agent 新建/继续/重试路由回归测试。
```

打开指定项目：

```powershell
.\protected-release\SiemensTIAAgent.exe --project "D:\path\to\project"
```

构建器会执行以下步骤：

1. 重新编译本地交互窗口。
2. 收集 Siemens PLC、WinCC、Openness、多平台 Agent 适配器、工作流和 skill 运行资源。
3. 排除交互窗口 C# 源码和构建中间文件。
4. 使用随机密钥进行 AES-256-CBC 加密，并使用 HMAC-SHA256 防篡改。
5. 生成自包含的 `win-x64` 单文件 EXE。
6. 执行内置载荷解密和结构自检。

## 运行时保护

- 运行资源只解密到当前用户的 `%USERPROFILE%\.codex\siemens-tia-agent-runtime\sessions` 临时目录，以便内置 Agent 子进程在其工作区沙箱中读取 skill。
- EXE 内置 Codex、Claude Code、Trae Agent 和 Qoder 的适配与路由配置，但不内嵌第三方 CLI、商业模型、账号、Token 或 API Key；目标机器仍需按所选平台完成合法安装和授权。
- 临时目录会收紧为当前 Windows 用户访问，并设置隐藏和禁止内容索引属性。
- 交互窗口关闭后自动清理本次运行目录；异常残留会在下一次启动时清理。
- EXE 内置 HMAC 完整性验证，被修改或载荷损坏时拒绝启动。
- 保护版工作台生成的执行队列、变更包和 WinCC runner 会优先使用 `SIEMENS_TIA_RUNTIME_ROOT`，不会回退到发行包外的源码路径。
- 本次构建包含真实 WinCC 读取、克隆应用预检、中文路径日志解码和 C# runner 适配器修复。
- 可向构建脚本传入 `-CertificateThumbprint`，使用当前用户证书进行 Authenticode 签名。
- 工作台内置发布审批门禁：审查包携带 artifact fingerprint，生产应用绑定输入 XML SHA256、克隆编译证据、WinCC 布局状态和审批有效期；生产应用始终执行备份，不能使用 `-SkipBackup`。
- 工作台命令面板会在启动 PowerShell 前写入 `PLC_Code\console-jobs\*.json`，保存原始参数、配置快照、stdout/stderr、进程号、退出码和重试/继续关系；任务状态页支持重试、重放和打开日志。
- 工作台内置 Agent 对话同样写入 `*-agent-chat-*.json` 任务清单，并保存平台、模型、Agent、会话、提示词、附件与超时状态；任务页支持 Agent 回合的可审计重试和兼容会话继续。
- 保护版会把 `--run-command <command>` 转发给内置原生工作台；它仍使用同一套受控命令映射和安全门禁，可用于部署脚本和自动化验收。

## 保护边界

该方式适合避免直接分发 `.cs`、`.ps1`、`.md` 和 `.json`，并提高普通复制、修改和二次打包的门槛，但本地离线程序无法实现绝对不可逆保护。拥有管理员权限和逆向分析能力的人员仍可能读取进程内存或临时运行文件。

更高等级保护需要同时采用：私有源码仓库、代码签名、许可证校验，以及将关键生成算法或商业规则放到您控制的服务器端。当前公开 GitHub 历史中已经出现过的源码不会因为生成保护版 EXE 而自动消失。
