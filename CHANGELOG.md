# Changelog

## 2026-09-13 - WinCC 绑定类型与权限门禁，发行版 1.1.1

- 为 `wincc-binding-assistant` 增加 HMI/报警数据类型兼容性检查，精确匹配优先，数值转换保留人工复核，不兼容类型不再推荐。
- 增加 HMI `read/write/readwrite` 与 PLC 候选可写性检查，已确认只读的 PLC 变量不能作为写入目标。
- 审核应用阶段重新从当前导出证据解析批准绑定，阻止不在候选证据中的路径以及明确类型/权限不兼容的批准项。
- 审核报告和候选 CSV 增加请求类型、权限、兼容状态、原因和证据字段，并补充正向/负向回归测试。
- 保护版重新构建为 `1.1.1`，载荷 239 个文件，SHA256 为 `86E38CC978D708038F0F5293519719B86F42E94D400D4E3FB1B50655EC3ACDD5`，自检通过。

## 2026-09-13 - 工程契约与 WinCC 绑定审核增强，发行版 1.1.0

- 将 `engineering-contracts` 接入命令路由、自动开发流水线、项目对象模型、能力矩阵、工作台 Dashboard 和审查包。
- 新增 PLC-DB-WinCC 关联审查，区分已验证成员、仅块清单、缺少导出成员证据和明确缺失成员。
- 新增 `wincc-binding-assistant`，基于已导出的 DB 成员和 LAD 全局符号生成候选与评分，并通过人工批准 CSV 生成派生 HMI/报警导入清单。
- 原生工作台新增“工程契约”和“WinCC 绑定”入口，执行后自动打开对应审查报告。
- 保护版重新打包最新工作台逻辑；构建哈希、载荷数量和自检结果以实际构建结果为准。
- 修复保护版 `--run-command` 执行完成后不退出的问题；命令模式现在返回实际退出码，交互启动模式保持不变。

## 2026-09-13 - WinCC 绑定审核闭环与发行版 1.0.9

- 新增 `wincc-binding-assistant`，从已导出的 DB 成员和 LAD 全局符号生成带评分、数据类型、可写性、证据来源和候选理由的 WinCC PLC 绑定表。
- 新增 `binding-review.csv` 人工审核流程；批准后生成派生 HMI/报警清单，支持可选备份后写回工程内 WinCC 包，不触碰 TIA 内部二进制或生产 PLC。
- 修复 `source` CSV 元数据被误识别为 PLC 绑定的问题。
- 新增 Windows PowerShell 5.1 UTF-8 BOM 兼容夹具，覆盖候选生成、审核回放、派生清单和绑定误判防护。
- 本地工作台新增 WinCC 绑定审核入口，生成完成后自动打开审核报告。

## 2026-09-13 - 工程契约证据分级与发行版 1.0.8

- 新增 `engineering-contracts` 的 DB 证据模型和 `db-evidence-index.csv`，区分已验证 DB 成员、仅有块清单、无成员 XML 和明确缺失成员。
- LAD 中引用仅在成员 XML 已提供且路径不存在时生成 `FAIL/MISSING_DB_MEMBER`；块存在但成员未导出时生成 `WARN/EVIDENCE_GAP/UNVERIFIED_DB_MEMBER`。
- 运动、通信、IEC 定时器/计数器等未出现在当前 block-list 的实例 DB 改为证据缺口 WARN，并记录系统/库实例类别，避免把导出不完整误判为实例已缺失。
- WinCC 标签和报警支持 `plcPath`、`plcTag`、`binding`、`plcVariable`、`address` 字段，以及 `tag-contract.md` 中的 `PLC Binding` 列；输出绑定来源、数据类型和解析状态。
- 项目模型、工作台仪表盘和审查包新增证据缺口、DB 成员证据覆盖率等指标。
- 新增夹具覆盖完整证据、仅块清单和明确缺失成员三种场景；通过工程契约、LAD 差异、Agent 路由和工作台 job 持久化回归测试。
- 保护版升级为 `1.0.8`，载荷 236 个文件，SHA256 为 `D6FA4FD15C962EECB8EBCD054927DC04316E5F9C56E14528358C89A4AE1FF894`，自检通过。

## 2026-09-13 - LAD 结构差异审查

- 新增通用 `lad-diff` 命令，按网络比较导出块的标题、注释、编程语言、指令、符号、部件、连线和去 `UId` 结构签名。
- 工作台 `LAD结构编辑` 页新增 `LAD差异` 按钮，并接入代码菜单、运行菜单和命令面板。
- 差异结果同时写入 `PLC_Code\lad-diffs\latest-lad-diff.md/json`，可作为 AI 审查和发布审批前置证据，但不替代 TIA 克隆编译。
- 新增 `test-lad-diff.ps1` 离线回归测试，覆盖无变化和单网络修改两种场景，并修复 Windows PowerShell 5.1 中文脚本 UTF-8 BOM 兼容性。

## 2026-09-13 - Agent 工程上下文注入

- 工作台每个 Agent 回合自动生成受控 `context-manifest.json`，绑定工程总览、项目模型、计划、队列、知识包、能力矩阵、PLC 指令路由、WinCC 证据和仿真证据。
- `invoke-ai-platform-agent.ps1` 新增 `-ContextManifest`，校验清单中的文件必须存在且位于当前项目目录，并将上下文作为只读证据注入各平台提示词。
- `platform.selected` 事件和 `PLC_Code\console-jobs` 任务清单现在记录实际上下文清单及文件数量，重试/继续会复制上下文输入证据。
- `queue-run-current` 自动创建阶段级上下文清单，避免队列 Agent 只拿到项目路径或无边界地扫描历史克隆。
- 修复项目模型版本探测误选 `.info` 文件的问题，现在严格识别 TIA Portal `.ap16` 到 `.ap21` 项目文件。

## 2026-09-13 - Agent 对话统一任务审计

- 将工作台内置 Codex、Claude Code、Trae Agent 和 Qoder 的每次对话接入 `PLC_Code\console-jobs` 任务模型，不再只保存在 `agent-sessions` 目录。
- Agent 任务在进程启动前创建 manifest，并记录提示词、附件清单、配置快照、请求/实际平台、模型、Agent、兼容会话 ID、stdout/stderr、进程号和最终状态。
- 任务状态页现在可以查看 Agent 详情、打开日志，并对 `agent-chat` 执行可审计重试或兼容会话继续；继续明确是进程级重放，不伪装成断点恢复。
- 增加 Agent 回合超时处理：超过工作流配置的超时限制会终止子进程树并记录失败原因；工作台关闭或进程消失后刷新会标记中断任务。
- 修复工作台烟囱测试的进程清理变量和 `WaitForExit` 输出问题。

## 2026-09-13 - Agent 重放可靠性增强

- `RETRY` 会复制原始 prompt 和附件清单，并明确清除旧会话参数，避免误恢复历史上下文。
- `CONTINUE` 会复制同一份输入证据，并仅在记录的平台与当前会话平台匹配时恢复会话。
- 命令与 Agent 的停止、超时状态改为任务级审计字段，降低旧进程退出事件污染新任务状态的风险。
- 新增离线 `test-agent-routing-and-replay.ps1`，无需联网或真实 AI 账号即可验证新建、继续和重试路由契约。

## 2026-09-10 - 发布审查与审批门禁 1.0.5

- 新增原生“发布审批”页面，显示导入就绪、克隆编译、WinCC 布局、哈希和审批状态。
- 新增 `review-approval`：支持待审批、克隆批准、生产批准、拒绝和发布清单。
- 生产审批绑定项目路径、输入 XML SHA256、审查包指纹、成功克隆编译证据、WinCC 布局状态和有效期。
- `apply-release` 会重新校验全部门禁并禁止 `-SkipBackup`；WinCC 克隆应用也必须存在批准记录。
- 新增中文审批脚本 UTF-8 BOM 兼容处理，避免 Windows PowerShell 5.1 乱码解析。

## 2026-09-10 - WinCC 布局校验与保护版 1.0.4

- 修复 Windows PowerShell 5.1 直接执行无 BOM UTF-8 脚本时的误解析，WinCC 设计工作流脚本改为 UTF-8 BOM。
- 修复布局校验结果生成顺序错误，避免在校验对象初始化前写出空报告。
- 新增画面边界、组件尺寸缺失和同画面矩形重叠校验，输出 `layout-validation.json/md`，并把状态接入工作流报告、布局网格和工作台预览。
- 已用正常规格验证 `PASS / overlap=0 / out-of-bounds=0`，用故意重叠规格验证 `REVIEW_REQUIRED / overlap=1`。
- 保护版重新构建为 `1.0.4`，载荷 227 个文件，自检通过。

## 2026-09-10 - WinCC 设计工作区闭环

- 修复原生工作台 WinCC 设计页缺失列表模型和结果展示方法导致的编译失败、启动不可用问题。
- 新增 WinCC 设计 JSON 保存校验，保存前自动备份旧规格；删除列表项后立即同步右侧 JSON。
- 新增 `run-wincc-design-workflow.ps1` 的用户规格一致性处理：画面、组件、坐标、尺寸、类型、标签和报警会进入下游 CSV 与实现清单。
- 修复 Windows PowerShell 5.1 中 `$LASTEXITCODE:` 的变量解析错误。
- `wincc-design-workflow` 已在当前 V17 工程实际运行通过，生成 3 个画面、6 个组件、8 个 HMI 标签、3 个报警，并保持克隆专用、生产不写入、PLC 不下载。

## 2026-09-10 - 原生 LAD 结构编辑工作区

- 新增 Windows Forms `LAD结构编辑` 页，提供网络号、标题、注释、条件链和动作链编辑。
- 支持 `NO/NC/P_EDGE/N_EDGE`、比较条件、`COIL/SET/RESET`、`TON/TOF/TP`、`MOVE`、`CTU/CTD/CTUD` 和通用 `CALL` 的常用输入。
- 右侧保留完整 LAD JSON 自由编辑入口，可继续使用分支、CALL 参数、数组成员、作用域和其他脚本已支持的高级字段。
- `从XML读取` 会从导出 XML 恢复常见网络摘要；`生成XML`、`校验XML`、`克隆验证` 已接入真实脚本和原有安全门禁。
- 保存和覆盖 `PLC_Code\lad-editor` 产物前自动建立时间戳备份；不会直接修改 TIA 内部二进制工程，也不会下载 PLC。
- 修复新 LAD 页在 WinForms 首次布局时设置 SplitContainer 最小尺寸导致的启动崩溃。

## 2026-09-10 - 保护版工作台运行时修复

- 修复保护版 EXE 解密目录位于 `AppData\Local` 时，内置 Codex Agent 子进程无法读取 skill 的问题。
- 保护版运行时改为使用用户 `.codex` 下的随机临时会话目录，并继续保留隐藏、用户 ACL、退出清理和 HMAC 校验。
- 修复执行队列和 PLC 变更包生成器，生成命令始终引用当前运行中的 skill 包。
- 修复 WinCC Openness C# skeleton 和 PowerShell runner，优先读取 `SIEMENS_TIA_RUNTIME_ROOT`。
- 通过保护版窗口真实触发 PLC 变更包、Agent 执行队列和当前阶段运行；确认 Agent 能读取内置 WinCC skill，未发生 `Access denied` 或生产工程写入。
- 保护版版本标记为 `1.0.1`，载荷文件数为 225，自检通过。

## 2026-09-10 - 真实工作台执行链路

- 验证安装目录中的 `PLCDevConsole.exe` 可启动并保持响应，窗口内可见项目树、日志、文件预览、AI 交互和工作流按钮。
- 通过 Windows UI Automation/Win32 真实触发“WinCC读取”和“WinCC克隆应用”，确认按钮会启动实际 PowerShell 工作流并生成项目内日志与回读证据。
- 修复工作台命令通道对 Windows PowerShell 5.1 中文输出的解码问题，中文 TIA 工程路径在日志和预览中保持可读。
- WinCC 读取流程已在当前 V17 工程生成真实 `wincc-readback.json`；因工程没有 HMI 目标，克隆应用流程明确阻断并记录“未克隆、未写入”证据。
- 修复 WinCC Openness 脚手架生成的 C# 适配器，使其调用受保护的克隆执行 runner，不再生成 `NotImplementedException` 占位实现。
- 保护版单文件 EXE 重新构建并通过自检，载荷文件数为 225，生产写入和 PLC 下载仍保持关闭。

## 2026-09-09 - Agent workbench orchestration

- Added `plc-instruction-cookbook`, producing a reusable Siemens instruction route matrix and risk checklist for LAD JSON, generic `CALL`, SCL source import, donor LAD network and technology-object workflows.
- Added `wincc-component-blueprints`, producing reusable WinCC screen/component blueprints, layout grid JSON, SiVArc rule notes and CWC manifest stubs for reference-image/text-to-editable-HMI work.
- Added `wincc-engineering-scaffold`, producing WinCC engineering task lists, HMI tag/alarm import maps, faceplate build lists, SiVArc/CWC checklists, runtime smoke plans and clone-validation plans.
- Added `simulation-package`, producing static validation, clone compile, readback diff, PLCSIM Advanced hook, WinCC Unified GraphQL smoke and release-gate scenarios for project-level verification.
- Extended `agent-pipeline` so broad PLC/WinCC tasks now generate project model, knowledge pack, capability map, PLC instruction cookbook, instruction plan, WinCC plugin routing, visual package, component blueprints, WinCC engineering scaffold, simulation package, Agent plan, execution queue and workbench dashboard in one auditable pass.
- Fixed the new Chinese PowerShell workflow scripts for Windows PowerShell 5.1 by avoiding inline object subexpressions and saving the files with UTF-8 BOM to keep bilingual `中文_English` naming safe.
- Added native workbench task planning through `agent-plan`, producing `PLC_Code\agent-plans\latest-plan.md/json`.
- Added native workbench execution queues through `agent-queue`, producing `PLC_Code\agent-queues\latest\queue.md/json`, stage prompts, logs and evidence folders.
- Added queue stage control through `queue-stage`, including start-next, complete-current, fail-current, block-current and reset actions with `current-stage.md/json`.
- Added workbench review packages through `review-package`, collecting Agent plans, queues, PLC/WinCC packages, artifact hashes, optional git diffs and import-readiness gates.
- Added `project-model`, producing `PLC_Code\workbench\context\latest\project-model.json`, `agent-context.md`, and `file-index.csv` as the fast project understanding layer for local and cross-platform Agents.
- Added `knowledge-pack`, producing official-first PLC/WinCC source packs with Siemens documentation anchors, reviewed-community routing notes, task-specific retrieval queries and Agent prompt handoff files.
- Added `capability-map`, producing `PLC_Code\workbench\capabilities\latest\capability-map.md/json` so the native workbench can honestly track editor-replacement coverage, validation gates, TIA-native gaps and next steps.
- Added one-click Agent development pipelines through `agent-pipeline`, automatically generating PLC instruction plans, WinCC visual packages, Agent plans, execution queues and dashboard evidence from one broad PLC/WinCC request.
- Added `任务编排` and `项目模型` tabs, toolbar/menu actions and auto-preview after plan/context generation.
- Added toolbar/menu/settings-panel entries for execution queue generation, current-stage handling and review-package preview.
- Added dashboard coverage for the latest `agent-pipeline` summary so the validation panel shows end-to-end pipeline state.
- Added read-only TIA Viewer / ImportExport adapter discovery and `wincc.tiaViewerPath` configuration for future offline SimaticML, LAD/FBD, GRAPH, SCL, DB and UDT previews.
- Added editable file preview with backup-on-save and a `lad-preview` action for readable LAD XML summaries.
- Added `plc-change-package` for structured PLC edit packages with contracts, LAD JSON, SCL/DB folders, import manifests, verification plans and safety notes.
- Added workflow routes for `工作台自动开发`, `PLC高级指令与工艺对象` and `安全风险评估`.
- Added dedicated `工作台编排 Agent`, `PLC 高级指令工程师` and `队列执行 Agent` profiles.
- Added references for agent workbench evolution, advanced PLC instruction/technology-object routing, and visual-to-WinCC engineering.
- Updated WinCC visual workflow with a multi-stage reference-image/text-to-editable-WinCC pipeline, component selection matrix, plugin invocation plan, CWC/Faceplate package notes and engineering task JSON.
- Updated the native workbench toolbar, run/tools menus, settings panel, dashboard, capability map and project model previews for WinCC engineering scaffolds and simulation packages.
- Added `wincc-openness-implementation`, producing clone-only WinCC screen/object maps, HMI tag/alarm implementation inputs, an Openness C# skeleton and a guarded runner.
- Added `simulation-replay`, producing six scenario evidence results and readiness checks for clone compile, PLCSIM Advanced and WinCC Unified runtime smoke.
- Extended the native console with WinCC implementation and simulation replay buttons, menus, settings actions, command routing and automatic result previews.
- Fixed new Windows PowerShell 5.1 workflow scripts by writing them with UTF-8 BOM encoding.
- Fixed native workbench startup when no project path is supplied: current-TIA detection now waits until the WinForms window handle exists, preventing `BeginInvoke` startup crashes.

## 2026-09-09

- Reworked the native console AI interaction area into a responsive two-row settings grid, a non-overlapping attachment/status bar, and compact send/stop/session/draft controls.
- Added a unified multi-platform Agent router for Codex, Claude Code, Trae Agent, and Qoder with automatic task-based selection and strict manual selection.
- Added workflow-specific platform priorities, models, Agent profiles, skills, and instructions for project reads, LAD, SCL, DB/HMI contracts, WinCC, Openness, diagnostics, industrial refactors, and reviews.
- Added persistent platform settings, command overrides, session-platform isolation, custom model IDs, and platform health checks to the native Windows console.
- Kept third-party CLIs and authentication external: the protected EXE embeds adapters and workflows, not vendor binaries, accounts, models, or API keys.

## Unreleased

- Added a self-contained `SiemensTIAAgent.exe` protected release path with an encrypted skill/runtime payload, HMAC integrity checks, per-user temporary extraction, cleanup, optional Authenticode signing, and a build-time self-test.
- Integrated Codex CLI Agents directly into the native console with selectable Siemens roles, continuous sessions, file attachments, JSONL conversation rendering, stop controls, and project-local audit logs.
- Added `setup-siemens-tia-suite.ps1`, built-in Agent profiles, and a dependency manifest for one-command skill, Agent runtime, dependency, and EXE setup.
- Fixed WinCC plugin routing under Windows PowerShell 5.1 by preserving UTF-8 BOM encoding, and normalized missing SiVArc paths to an empty string in generated reports.

- Extended the packaged Openness bridge from a V17-only assumption to version-aware routing across TIA Portal V16 through V21.
- Added shared TIA version resolution, `.ap17` through `.ap21` project detection, and V21 modular assembly handling for helper builds and scaffolds.
- Added a version-compatibility reference that captures the V16-V21 differences most relevant to Openness, XML, and SIMATIC SD workflows.
- Expanded the WinCC HMI skill with screen hierarchy, navigation, visual consistency, and alarm/diagnostic layout guidance.
- Added `siemens-wincc-hmi-dev` for WinCC HMI automation workflows.
- Updated the release package metadata and installer to include the WinCC skill.
- Expanded `siemens-tia-plc-dev` with instruction-routing guidance so most Siemens instruction families can be routed through LAD JSON, generic `CALL`, SCL source import, or donor-network patching.
- Added direct LAD JSON generation support for `TOF`, `TP`, `CTD`, and `CTUD`, plus new reusable example specs.
- Updated `summarize-lad-xml.ps1` to read back `TOF`, `TP`, `CTD`, and `CTUD` networks into human-readable summaries.
- Hardened the Openness workflow with structured readiness fields in `probe-tia-v17.ps1`, a `doctor` alias in the generic wrapper, and fail-fast preflight checks before live Openness commands or clone-based LAD verification.
- Added `read-cycle` as the standard project intake command for probe, PLC/block listing, LAD/FBD/SCL export, LAD summaries, template catalog, and workflow reports.
- Added `write-cycle` as the standard generated-LAD safety gate: clone verification, import, compile, post-import export, readable summary, and release-package preparation only after successful compile.
- Hardened `write-cycle` observability with `current-step.json`, stdout/stderr temp logs, and `-StepTimeoutSeconds` to avoid black-box live Openness waits.
- Added a native Windows Forms `PLCDevConsole.exe` workflow console with project tree browsing, run/log preview, common workflow buttons, generated LAD XML write-cycle entry, and a Codex-ready AI task composer.
- Kept the earlier browser console as the explicit `console-web` fallback while making `console` / `console-exe` open the native executable.
- Refined the native console visual design with an industrial gradient header, card-style sections, rounded action buttons, styled project tree, clearer run list, and terminal-like log preview areas.
- Upgraded the native console into a resizable desktop cockpit with automatic TIA project detection, browse/open actions, draggable left project tree, switchable AI/log/preview pages, bottom model/workflow task input, and Windows font-library selection.
- Added WinCC visual AI routing to the native console: task-aware model defaults, API/image parameter controls, reference-image upload and preview, and generated component-mapping/design prompts for text-to-image or image-to-image HMI workflows.
- Added an IDE-style native menu bar with File/Edit/View/Navigation/Code/Refactor/Run/Tools/Git/Window/Help menus, moved settings into a scrollable Tools drop-down panel, and reduced bottom-panel crowding to prevent overlapping controls.
- Trimmed the native console header into a compact one-line project toolbar and wrapped the main workspace in a right-side scrollable canvas with mouse-wheel support.
- Reworked the native console command area into separate fixed rows for workflow buttons, LAD/XML inputs, and content tabs, and corrected dock ordering so scrollable content no longer slips underneath the menu bar.
- Added an AI-area quick configuration row and project-level `PLC_Code\config\ai-workflow.json` persistence; read/write cycles now consume the configuration, enforce its session and safety choices, and archive a snapshot in each workflow report.
- Added version-aware WinCC plugin discovery and routing for bundled image generation, local Openness/SiVArc, reviewed TIA MCP adapters, Unified screen-script export, GraphQL runtime validation, and Custom Web Control references.
- Added a WinCC visual AI workflow reference for turning uploaded screenshots or text descriptions into WinCC-native screens, faceplates, tags, alarms, navigation, and SiVArc/Openess implementation plans.
- Validated the installed skill path after TIA/Openness reinstall on 2026-09-07: `read-cycle -ProjectPath "D:\plc\手动程序" -Attach -SkipExport` detected `V17` and `PLC_1`.
- Added a reusable knowledge-retrieval reference plus broader official instruction-family links for math, conversion, string, word-logic, and shift/rotate routes.
- Added new source-backed training examples for analog scaling/conditioning and status-word packing/decoding.
- Added root-level `CLAUDE.md` and `.cursorrules` files so the same repository instructions work in Claude Code and Cursor.

## 1.0.0 - 2026-08-10

- Packaged the reusable Siemens TIA Codex skill suite into a distributable repository.
- Included `siemens-tia-plc-dev`, `tia-portal-v17`, and `codex-tia-client`.
- Hardened the release copy so sibling skills resolve locally before falling back to `%USERPROFILE%\.codex\skills`.
- Excluded machine-local Siemens runtime binaries, caches, and transient artifacts from the distributable package.
- Preserved validated LAD authoring, import, compile, and readback workflows, including timer-backed and batch LAD cases.
- Sanitized machine-specific paths so the repository can be published as a reusable public release.
