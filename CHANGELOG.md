# Changelog

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
