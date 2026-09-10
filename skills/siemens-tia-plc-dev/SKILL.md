---
name: siemens-tia-plc-dev
description: "Use for general Siemens TIA Portal PLC engineering across projects: backing up projects, probing Openness readiness, building PLC-as-code workspaces, reading and writing SCL/LAD/FBD via exported artifacts, generating reusable ladder templates, previewing imports, compiling on backup projects, and routing between Openness, exported XML, PLCopen XML, MCP, or GUI fallback."
---

# Siemens TIA PLC Dev

Use this skill when Codex should act like a practical Siemens PLC development partner rather than a generic coding assistant.

This skill is project-agnostic. It is designed for:

- new or existing TIA Portal projects
- S7-1200 and S7-1500 program work
- SCL and LAD/FBD engineering
- exported XML review and generation
- reusable template-library building
- backup-first import and compile loops
- release-package preparation and controlled project application
- local REST bridge patterns for editor-to-TIA communication
- VS Code client scaffolding for the local REST bridge

## Core workflow

Treat PLC work like software work:

1. Back up the project.
2. Probe the local TIA/Openness environment and stop live Openness work if the current logon token is not ready.
3. Initialize a `PLC_Code` workspace next to the project.
4. Export blocks to text/XML.
5. Review or edit exported artifacts.
6. Build summaries, catalogs, and reusable templates.
7. Preview imports before applying.
8. Compile on a backup project.
9. Re-export and compare.

For the generic workflow, read `references/workflow.md`.
For the native console configuration schema and execution mapping, read `references/ai-workflow-config.md`.
For the long-term native Agent workbench target and task planning gate, read `references/agent-workbench.md`.

## Native visual console

Use the local visual console when the user wants a better interaction surface than terminal commands. The default `console` command builds and opens a native Windows Forms `PLCDevConsole.exe` window with:

- automatic current-TIA-project detection plus browse/open actions for `.ap16` through `.ap21`
- an IDE-style top menu for file, view, navigation, code, refactor, run, tools, Git, window, and help actions
- a compact one-line project toolbar that avoids duplicating menu actions
- a scrollable main canvas with a right-side vertical scrollbar and mouse-wheel support when the window is shorter than the content
- a draggable left project tree for TIA projects, exported XML/SCL/DB/UDT, reports, and logs
- switchable center pages for AI chat, command logs, file preview, runs, and reference-image preview
- a bottom AI task box focused on the user request, with settings moved into the Tools menu to avoid crowding
- direct built-in Agent conversations through Codex, Claude Code, Trae Agent, or Qoder, with automatic task routing, manual platform/model overrides, compatible session handling, stop/new-session controls, and no separate AI window
- project-local file uploads for images, PDFs, documents, source files, exported XML, and logs
- a responsive two-row quick-configuration grid in the AI area for routing mode, platform, Agent, model, workflow, language preference, TIA session mode, safety mode, and step timeout, without horizontal control overlap
- a scrollable Tools settings panel for platform command overrides, model/workflow selection, API provider/base/key-env settings, image workflow/model/quality/size, WinCC component strategy, Windows font settings, and uploaded reference image path
- project-level configuration persistence at `PLC_Code\config\ai-workflow.json`; `read-cycle` and `write-cycle` consume the saved file and copy a snapshot into their run reports
- common workflow buttons for `doctor`, `read-cycle`, `list-blocks`, and `write-cycle`
- a native `LAD结构编辑` page with condition/action entry lists, bilingual titles/comments, editable LAD JSON, XML generation, XML validation, XML readback summary, and clone verification actions wired to the real PowerShell helpers
- a native `WinCC设计编辑` page with editable screen/component/tag/alarm lists, free-form design JSON, save-time validation and backup, design-package compilation, component coordinates, geometry overlap/bounds validation, and automatic report/implementation preview
- native task orchestration through `agent-plan`, with a center `任务编排` tab that shows stages, tools, outputs, verification gates, safety gates, and release boundaries
- native execution queue generation through `agent-queue`, converting a plan into stage prompts, command suggestions, verification gates, logs and evidence folders
- queue state control through `queue-stage`, supporting start-next, complete-current, fail-current, block-current and reset transitions with current-stage previews
- one-click current-stage Agent execution through `queue-run-current`, which reads the active stage prompt, routes it to the configured platform/model, records stdout/stderr plus evidence, and keeps production writes behind review gates
- project object models through `project-model`, generating `PLC_Code\workbench\context\latest\project-model.json`, `agent-context.md`, and `file-index.csv` for fast cross-Agent understanding of TIA version, blocks, DBs, exported artifacts, WinCC packages, queues and safety gates
- task knowledge packs through `knowledge-pack`, generating official-first source lists, community adapter notes, task-specific search queries, implementation patterns, and Agent retrieval prompts under `PLC_Code\knowledge\packs\latest`
- editor-replacement capability maps through `capability-map`, generating a concrete matrix of native workbench coverage, backing commands, validation gates, TIA-native gaps, and next engineering steps under `PLC_Code\workbench\capabilities\latest`
- one-click Agent development pipeline through `agent-pipeline`, which detects PLC/WinCC scope from the task, generates instruction routing, WinCC visual packages, Agent plans, execution queues and dashboard evidence in one auditable pass
- workbench review packages through `review-package`, collecting plans, queues, PLC/WinCC packages, artifact hashes, git diffs and import-readiness gates
- workbench dashboard generation through `workbench-dashboard`, feeding the native validation and diff panels with queue health, latest run reports, import readiness, plugin routing and Git diff summaries
- PLC instruction and technology-object route planning through `plc-instruction-plan`, producing instruction families, preferred authoring surfaces, verification gates and safety-risk notes
- PLC instruction cookbooks through `plc-instruction-cookbook`, producing a reusable route matrix for bit logic, compares, timers, counters, motion, drives, communication, PID, diagnostics, arrays, recipes, math and conversion families
- WinCC component blueprints through `wincc-component-blueprints`, producing reusable screen shells, alarm strips, station cards, motor/cylinder/drive panels, trends, parameter panels, diagnostics tables, SiVArc rule notes and CWC manifest stubs
- WinCC engineering scaffolds through `wincc-engineering-scaffold`, producing preflight checks, HMI tag/alarm import maps, faceplate build lists, SiVArc/CWC checklists, runtime smoke plans and clone-validation plans
- WinCC Openness implementation packages through `wincc-openness-implementation`, turning the engineering scaffold into HMI tag/alarm/screen object maps, packaged inputs, a real clone-only runner, and readback evidence
- simulation and runtime validation packages through `simulation-package`, producing clone compile scenarios, I/O simulation contracts, PLCSIM Advanced hook notes, WinCC Unified smoke notes and release-gate evidence
- simulation scenario replay reports through `simulation-replay`, turning simulation scenarios into an evidence matrix that checks latest write-cycle, project-model, PLCSIM and WinCC runtime readiness without downloading to hardware
- editable file preview with backup-on-save to `PLC_Code\file-backups`, plus `lad-preview` for readable LAD XML summaries
- PLC change packages through `plc-change-package`, creating a structured editing workspace for DB contracts, LAD JSON, SCL sources, import manifests, verification plans, and safety risk notes
- run and log preview panels for `PLC_Code\runs` and `PLC_Code\console-jobs`
- an AI-platform-ready prompt file writer under `PLC_Code\ai-prompts`, plus auditable Agent requests, selected-platform events, and JSONL logs under `PLC_Code\agent-sessions`

Start it with:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" console -ProjectPath "D:\path\to\project"
```

Use `console-exe` explicitly when you want the native executable route, or `console-web` only as a fallback browser-based console. The native console uses `agents/ai-platforms.json`, `agents/siemens-workflow-routes.json`, and `scripts/invoke-ai-platform-agent.ps1` to route each task to an installed platform. Automatic mode skips unavailable platforms; manual mode fails clearly instead of falling back. Read `references/agent-console.md` for platform adapters, Agent profiles, attachments, sessions, and safety boundaries.

## Local bridge

This release keeps the legacy sibling skill name `tia-portal-v17`, but the packaged bridge now routes TIA Portal `V16` through `V21`.

Use the wrapper scripts in this skill to stay generic:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\bootstrap-siemens-plc-dev.ps1" -ProjectPath "D:\path\to\project"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\refresh-plc-libraries.ps1" -ProjectPath "D:\path\to\project"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" console -ProjectPath "D:\path\to\project"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" agent-chat -ProjectPath "D:\path\to\project" -PromptFile "D:\path\to\message.txt" -AgentId auto -Workflow plc-lad -RoutingMode auto -Platform auto -Sandbox workspace-write -Search
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" agent-plan -ProjectPath "D:\path\to\project" -TaskText "Generate an industrial PLC and WinCC upgrade plan" -Workflow agent-workbench
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" agent-queue -ProjectPath "D:\path\to\project" -TaskText "Generate auditable execution queue from the latest plan"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" queue-stage -ProjectPath "D:\path\to\project" -Action start-next
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" queue-run-current -ProjectPath "D:\path\to\project" -RoutingMode auto -Platform auto -Sandbox workspace-write -TimeoutSeconds 900 -Search
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" project-model -ProjectPath "D:\path\to\project" -TaskText "Build Agent context for this project"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" knowledge-pack -ProjectPath "D:\path\to\project" -TaskText "Build official-first PLC/WinCC knowledge pack" -RefreshOnline
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" capability-map -ProjectPath "D:\path\to\project" -TaskText "Assess local workbench replacement coverage"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" agent-pipeline -ProjectPath "D:\path\to\project" -TaskText "Generate PLC/WinCC engineering plan, queue and dashboard" -RefreshWinccCatalog
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" review-package -ProjectPath "D:\path\to\project"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" workbench-dashboard -ProjectPath "D:\path\to\project"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" plc-instruction-cookbook -ProjectPath "D:\path\to\project" -TaskText "Build reusable Siemens instruction cookbook"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" plc-instruction-plan -ProjectPath "D:\path\to\project" -TaskText "Add Modbus drive control with HMI diagnostics"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" wincc-component-blueprints -ProjectPath "D:\path\to\project" -TaskText "Build reusable WinCC component blueprints"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" wincc-engineering-scaffold -ProjectPath "D:\path\to\project" -TaskText "Build WinCC engineering scaffold"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" wincc-openness-implementation -ProjectPath "D:\path\to\project" -ForCloneOnly
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" wincc-design-workflow -ProjectPath "D:\path\to\project" -DesignSpecPath "D:\path\to\project\PLC_Code\wincc\editor\latest-design.json" -ForCloneOnly
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" simulation-package -ProjectPath "D:\path\to\project" -TaskText "Build simulation and runtime validation package"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" simulation-replay -ProjectPath "D:\path\to\project"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" plc-change-package -ProjectPath "D:\path\to\project" -TaskText "Add a motor interlock change" -Workflow plc-lad
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" probe-ai-platforms
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" doctor -ProjectPath "D:\path\to\project"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" read-cycle -ProjectPath "D:\path\to\project" -UseUi
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" list-blocks --project "D:\path\to\project"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" clone-project -ProjectPath "D:\path\to\project"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" verify-lad-change -ProjectPath "D:\path\to\project" -InputXml "D:\path\to\generated.xml" -PlcName "PLC_1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" write-cycle -ProjectPath "D:\path\to\project" -InputXml "D:\path\to\generated.xml" -PlcName "PLC_1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" prepare-release -ProjectPath "D:\path\to\project" -InputXml "D:\path\to\generated.xml" -ReleaseName "my-change"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" apply-release -ProjectPath "D:\path\to\project" -InputXml "D:\path\to\release.xml" -PlcName "PLC_1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" prepare-write-session -ProjectPath "D:\path\to\project"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\start-tia-rest-bridge.ps1" -Background
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\scaffold-vscode-rest-client.ps1" -ProjectPath "D:\path\to\project"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\scaffold-openness-console.ps1" -TargetDirectory "D:\path\to\OpennessConsole" -ProjectName "MyTiaTool"
```

For how the generic skill maps to the local `V16-V21` implementation, read `references/version-routing.md`.
For the version-by-version differences that affect assemblies, project suffixes, and document workflows, read `references/version-compatibility-v16-v21.md`.

If `doctor` or `probe` reports `ActiveInCurrentLogonToken = false`, do not keep retrying live Openness commands. Switch to source-only XML/SCL work for now and tell the user to fully sign out of Windows and sign in again before the next live TIA session.

After a fresh TIA Portal or Openness install, run the first live read with `read-cycle -UseUi` or `list-plcs --ui`. This lets Siemens show and complete any Openness trust/security prompt. After the first successful UI-backed read, use normal no-UI `read-cycle`, exports, imports, and compile loops.

## Read and write paths

Choose the narrowest path that fits the task:

- `read-cycle` for the standard read-first project snapshot: probe, list PLCs, list blocks, export LAD/FBD/SCL, summarize LAD, build a catalog, and write `PLC_Code\runs\<run>\workflow-report.json`
- exported XML and SCL for code-like review
- Openness for block traversal, export, import, and compile
- template manifests for reusable network patterns
- PLCopen XML for interchange and offline transformations
- MCP when available
- GUI only when automation cannot reach the target

## REST bridge

Use the local REST bridge when an editor, agent, or custom tool should talk to TIA through HTTP instead of loading TIA APIs directly.

For details, warm-session behavior, and request examples, read `references/rest-bridge.md`.
For a ready-to-copy VS Code starter, read `references/vscode-client-template.md`.
For GUI-assisted PLC download preparation, read `references/gui-download-bridge.md`.

## Direct Openness tooling

Use a direct C# Openness helper when you want a native engineering tool instead of routing through REST.

Scaffold a minimal console project that references the correct Openness assemblies for `V17` through `V21`:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\scaffold-openness-console.ps1" -TargetDirectory "D:\path\to\OpennessConsole" -ProjectName "MyTiaTool"
```

For the official-source baseline behind this route, read `references/official-openness-sources.md`.

## LAD strategy

Use LAD exports as structured XML, not as casual free text.

For ladder-specific reading, summaries, template generation, and import preview, read `references/lad-and-templates.md`.
For how to cover most Siemens instruction families without forcing every case through one fragile LAD syntax, read `references/instruction-routing.md`.
For advanced instructions, technology objects, drives, communication and risk gates, read `references/advanced-plc-automation.md`.
For how to retrieve official and community knowledge during authoring, read `references/knowledge-retrieval.md`.
For naming and comment style, read `references/naming-and-comments.md`.
For training notes and the latest ladder-writing lessons, read `references/lad-training-notes.md`.

For a code-like edit loop around one ladder change, scaffold a working set:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" scaffold-lad-change -ProjectPath "D:\path\to\project" -SourceXml "D:\path\to\block.xml" -ChangeName "cylinder-3-timeout-cleanup"
```

Then use a one-command safe verification loop on a cloned project:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" verify-lad-change -ProjectPath "D:\path\to\project" -InputXml "D:\path\to\project\PLC_Code\changes\my-change\outputs\my-change.generated.xml" -PlcName "PLC_1"
```

When you want to reuse one exported network instead of editing a whole block shell, patch only `NetworkSource` / `FlgNet`:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" patch-lad-network -TargetXml "D:\path\to\target.xml" -DonorXml "D:\path\to\donor.xml" -OutputXml "D:\path\to\patched.xml" -TargetNetworkIndex 1 -DonorNetworkIndex 1 -CopyTitle -CopyComment
```

When you want a first free-write path for simple ladder logic, write a JSON spec and compile it into one network:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" scaffold-lad-network-json -OutputPath "D:\path\to\network.json" -Title "Alarm rung"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" write-lad-network -TargetXml "D:\path\to\block.xml" -SpecPath "D:\path\to\network.json" -OutputXml "D:\path\to\generated.xml" -NetworkIndex 3
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" write-lad-batch -TargetXml "D:\path\to\block.xml" -ManifestPath "D:\path\to\batch-manifest.json" -OutputXml "D:\path\to\generated.xml"
```

Current supported free-write subset:

- series `NO` / `NC` contacts
- edge conditions `P_EDGE` and `N_EDGE`
- compare conditions `EQ`, `NE`, `GE`, `GT`, `LE`, `LT` with symbol or constant operands
- `conditionGroups` for parallel OR branches that merge through one `O` part
- shared-prefix `branches` where one upstream signal fans out into several downstream condition chains with per-branch actions
- one signal path with optional `TON`, `TOF`, or `TP`
- timer `pt` as either a time string such as `T#1s` or a symbol/components operand that resolves to a `TIME` variable
- one or more output actions per network
- `COIL`, `SET`, `RESET`, `TON`, `TOF`, `TP`, `MOVE`, `CTU`, `CTD`, `CTUD`, and generic `CALL`
- named `CALL` inputs and outputs with optional `open` connections
- `powerRail` on `CALL` and `MOVE`, and `signalTarget` on `CALL`
- `signalSource` on `MOVE` for action-to-action chaining such as `eno -> en`
- action-only `CALL` networks such as `MB_COMM_LOAD`
- `constantName` support for `GlobalConstant`
- `components` paths for array-style or nested variable access
- network title and comment
- `scope` support for `GlobalVariable` and `LocalVariable`

Current practical route for "most instructions":

- maintenance-facing bit logic, compares, timers, and counters: free-write LAD JSON
- motion, communication, drive, and technology/library blocks: generic `CALL` from exported interfaces
- arithmetic, scaling, conversion, string, word-packing, array, and bulk data handling: SCL source import by default
- unsupported LAD box shapes: export one donor network, then patch `NetworkSource` / `FlgNet`

For advanced or mixed-instruction tasks, run `plc-instruction-plan` before authoring. It writes `PLC_Code\plc\instruction-plans\latest\instruction-route-table.md/json`, `technology-object-plan.md`, and `safety-risk-assessment.md`. Use it to decide which parts belong in LAD JSON, generic `CALL`, SCL source import, donor LAD networks, or technology-object configuration before creating the actual change package.

For a generated LAD XML block, prefer `write-cycle` as the safe default before any real import. It verifies the block on a cloned project, compiles, re-exports, writes a readable summary, and prepares a release package only when compile succeeds. It does not write directly to the production project.

The native workbench LAD editor is a code-like authoring surface, not a screenshot mockup. Use `从XML读取` to recover a best-effort network summary, edit common contacts/actions from the structured lists, or directly edit the complete JSON in `LAD JSON`. `生成XML` calls `write-lad-network` against the selected exported block and writes `PLC_Code\lad-editor\latest.generated.xml`; `校验XML` calls the LAD validator; `克隆验证` routes that generated artifact through `write-cycle`. Complex branches, named CALL parameters, technology instructions, and uncommon box shapes remain available through direct JSON, donor-network patching, or the existing instruction-routing workflow. Read `references/lad-workbench-editor.md` when this page is the primary authoring surface.

If a live write verification takes longer than expected, inspect `PLC_Code\runs\write-cycle-*\current-step.json` and the matching `logs\*.stdout.tmp` / `logs\*.stderr.tmp` files before retrying. Do not start a second live TIA write/import command while the first one is still running.

For newly added timer/counter shapes such as `TOF`, `TP`, `CTD`, and `CTUD`, keep the normal clone compile gate until a project-specific validation has been recorded.

Current validated edge:

- `TON` works when the referenced timer instance DB already exists in the project
- writing a `TON` that points to a new missing instance name will import, but compile can fail with `Missing instance DB`
- `verify-lad-change` can now auto-import a sibling `supporting-sources` folder before the XML block import, which makes timer-backed changes with new `IEC_TIMER` instance DB sources verifiable on a clone
- `write-lad-network` now reports `TonInstancesSeenInTargetXml` and `TonInstancesMissingFromTargetXml` as a preflight hint
- real-project validation now also covers `CTU` with one `P_EDGE` count path and one separate reset-branch path on the FC5 automatic block
- real-project validation now also covers `MC_Power` on the FC2 step block
- real-project validation now also covers action-only `MB_COMM_LOAD` on the FC3 drive block
- real-project validation now also covers `MB_MASTER + MOVE` with array-style `DATA_PTR` access on the FC3 drive block
- real-project validation now also covers dual `MOVE` chaining through `signalSource` on the FC2 status network
- real-project validation now also covers shared-prefix branch LAD on the FC2 homing step 2 network
- real-project validation now also covers a full FC2 step-block batch rewrite across networks 1 through 16
- real-project validation now also covers mixed direct-action plus shared-branch LAD on the FC5 automatic block
- real-project validation now also covers `TON + MOVE` step transitions on the FC5 automatic block
- real-project validation now also covers a small FC5 sequence batch that mixes branch-driven motion logic and timer-driven step changes
- real-project validation now also covers a full FC5 automatic-sequence block rewrite across networks 1 through 36
- real-project validation now also covers `TON.PT` bound to a `GlobalDB` `TIME` member on the FC6 station-supervisor block

When authoring LAD, keep names human-readable and network titles short and explicit. For maintenance-facing logic, LAD is the preferred surface; for heavier algorithms, keep the logic in SCL and only expose the readable control layer in ladder.

## Classic project patterns

When the user asks for practical PLC programs or wants Codex to improve its own authoring quality, ground the next program in classic device patterns instead of improvising from scratch.

Read `references/classic-control-patterns.md` before writing:

- motor reversing starter
- manual/auto conveyor
- cylinder timeout logic
- alarm latch and ack/reset

The skill now includes small reusable source examples under:

- `examples/classic-scl/motor-fwd-rev`
- `examples/classic-scl/conveyor-auto-manual`
- `examples/classic-scl/cylinder-timeout-fc`
- `examples/classic-scl/alarm-latch-fb`
- `examples/classic-scl/sequence-station-fb`
- `examples/classic-scl/star-delta-starter-fb`
- `examples/classic-scl/dual-starter-cell-fb`
- `examples/classic-scl/station-supervisor-fb`
- `examples/classic-scl/material-handling-cell`
- `examples/classic-scl/analog-scaling-fc`
- `examples/classic-scl/status-word-builder-fc`
- `examples/classic-lad/start-stop-single-coil`
- `examples/classic-lad/tp-pulse-output`
- `examples/classic-lad/tof-delayed-dropout`
- `examples/classic-lad/ton-set-alarm`
- `examples/classic-lad/reset-fanout`
- `examples/classic-lad/batch-reset-plus-ton`
- `examples/classic-lad/or-branch-coil`
- `examples/classic-lad/eq-ton-set`
- `examples/classic-lad/eq-move-step`
- `examples/classic-lad/set-move-step`
- `examples/classic-lad/ctu-reset-step`
- `examples/classic-lad/ctd-load-step`
- `examples/classic-lad/ctud-bidirectional-counter`
- `examples/classic-lad/mc-power-call`
- `examples/classic-lad/mb-comm-load-call`
- `examples/classic-lad/mb-master-readfreq`
- `examples/classic-lad/motion-axis-core-batch`
- `examples/classic-lad/dual-move-eno-chain`
- `examples/classic-lad/shared-prefix-homing-branch`
- `examples/classic-lad/mixed-direct-branch-step`
- `examples/classic-lad/sequence-branch-ton-batch`

## Agent workbench target

When the user asks to replace separate AI clients with the native workbench, use `agent-plan` before large changes. The current workbench can host Agent chat, attachments, routing controls, logs, file previews, WinCC plugin scans and generated task plans. Treat full editor replacement as an incremental target: keep adding real workbench functions only when they call a script, save config, show an artifact, or run a verification gate.

Current workbench planning output:

- `PLC_Code\agent-plans\latest-plan.md`
- `PLC_Code\agent-plans\latest-plan.json`

The plan should become the execution backbone for multi-stage PLC/WinCC work: context read, knowledge retrieval, contract design, authoring, validation, risk review and release. Use `plc-change-package` as the source-editing unit for real PLC changes; use the workbench editable preview only for exported source/XML/Markdown/JSON artifacts, never for TIA internal binary storage.

Use `agent-queue` after or alongside `agent-plan` when the workbench should turn a plan into executable stage records. It writes `PLC_Code\agent-queues\latest\queue.md`, `queue.json`, stage prompts under `prompts`, log folders and evidence folders. Queue items are not production writes; they are an auditable backbone for one-stage-at-a-time Agent execution, verification and release gating.

Use `queue-stage` to move one queue stage at a time. `start-next` creates `current-stage.md/json` for the next pending stage, `record-current` records evidence without completing the stage, `complete-current` marks it done, and `fail-current` or `block-current` records a stop state for inspection.

Use `queue-run-current` when the workbench should act like the main AI client. It runs the current stage through `invoke-ai-platform-agent.ps1`, honors the saved routing/platform/model/sandbox/search/timeout settings, writes logs under `PLC_Code\agent-queues\latest\logs`, writes evidence under `PLC_Code\agent-queues\latest\evidence`, and leaves the stage `IN_PROGRESS` by default for human review. Add `-CompleteOnSuccess` only for low-risk read-only or documentation stages where automatic completion is acceptable.

Use `project-model` before broad edits or cross-platform Agent execution. It creates a lightweight project index from the latest read/export/package artifacts without scanning bulky release folders, and writes the engineer-readable context file that Agent stages should load first.

Use `knowledge-pack` before authoring or when the user asks for research-driven work. It prioritizes Siemens official docs and official GitHub examples, then current project artifacts, then reviewed community source. It writes `knowledge-brief.md`, `knowledge-pack.json`, and `agent-retrieval-prompt.md`; downloaded community binaries remain disabled until source, license, provenance and clone behavior are reviewed.

Use `capability-map` when the user asks whether the workbench can replace TIA Portal editing or when planning another major workbench increment. It writes `capability-map.md/json` with each capability's status, UI entry, backing command, validation gate, remaining native-TIA dependency and next step. Do not claim full editor replacement beyond the capabilities marked ready or clone-verified in this map.

Use `plc-instruction-cookbook` when the user wants broader Siemens instruction coverage. It writes `PLC_Code\plc\instruction-cookbook\latest\instruction-cookbook.md/json` and `instruction-risk-checklist.md`. Treat it as the reusable map from a requested instruction family to LAD JSON, generic `CALL`, SCL source import, donor LAD network or technology-object configuration.

Use `wincc-component-blueprints` when the user wants reusable HMI design building blocks or a reference-image-to-editable-WinCC workflow. It writes `PLC_Code\wincc\component-blueprints\latest\component-blueprints.md/json`, `screen-layout-grid.json`, `sivarc-rule-blueprints.md`, and `cwc-package-manifest.json`. These are design and engineering handoff artifacts, not direct production screen writes.

Use `wincc-engineering-scaffold` when a visual package or component blueprint needs to become a concrete WinCC engineering backlog. It writes `PLC_Code\wincc\engineering-scaffold\latest\wincc-engineering-scaffold.md/json`, `engineering-task-list.csv`, `hmi-tag-import-map.csv`, `alarm-import-map.csv`, `faceplate-build-list.md`, `sivarc-generation-checklist.md`, `cwc-build-review.md`, `wincc-runtime-smoke-plan.md`, and `clone-validation-plan.md`. Treat it as the bridge from design intent to clone-first Openness/SiVArc/CWC implementation.

Use `wincc-openness-implementation` after `wincc-engineering-scaffold` when the backlog should become a concrete clone-first implementation package. It writes `PLC_Code\wincc\openness-implementation\latest\README.md`, `implementation-manifest.json`, packaged CSV inputs, `screen-object-map.csv`, `WinccEngineeringSkeleton.cs`, and a runner that calls the real `wincc-apply-clone` workflow. The workbench can also call `wincc-read-cycle` for real HMI readback. Classic WinCC writes remain XML import-driven; Unified supports direct creation/update of the generated tag, screen and alarm objects. Never apply to a production project without backup, clone validation and explicit approval.

Use `simulation-package` when the user asks for simulation, virtual commissioning, verification, or a mature project-level validation loop. It writes `PLC_Code\simulation\latest\simulation-package.md/json`, `simulation-scenarios.csv`, `plcsim-advanced-hook-notes.md`, and `wincc-runtime-smoke-notes.md`. It prepares scenarios and hooks; it does not download to a PLC or run unsafe runtime writes by default.

Use `simulation-replay` after `simulation-package` when the workbench should show executable validation readiness instead of only a static plan. It writes `PLC_Code\simulation\replays\latest\replay-report.md/json` and `scenario-results.csv`, checking for clone compile evidence, project-model evidence, drive/communication instruction plans, PLCSIM Advanced detection and optional WinCC Unified GraphQL configuration. Treat missing evidence as a next-step status, not a reason to retry indefinitely.

Use `agent-pipeline` when the user wants the native workbench to own the first pass of a PLC/WinCC task. It classifies the task, generates the project model, knowledge pack, capability map, PLC instruction cookbook, PLC instruction plan, WinCC plugin routing, WinCC visual package, WinCC component blueprints, WinCC engineering scaffold, WinCC Openness implementation package, simulation package, simulation replay report, Agent plan, Agent queue and dashboard. It does not import, download, or write to the production project.

Use `review-package` before release or after a substantial Agent run. It writes `PLC_Code\review-packages\latest\review-summary.md`, artifact indexes, optional `git-diff.patch`, and `import-readiness.json`. Treat it like a local PLC/WinCC pull-request bundle.

Use `workbench-dashboard` to refresh the native validation and diff panels after any read, write, queue, WinCC or review action. It writes `PLC_Code\workbench\latest\dashboard.md`, `validation-summary.md`, `diff-summary.patch`, and `dashboard.json`.

## Guardrails

- Prefer backup projects for first imports.
- Do not modify internal TIA binary storage directly.
- Do not wait indefinitely on stalled downloads, websites, or blocked sessions; switch route.
- Do not run multiple TIA project-open actions in parallel.
- Save after compile when the workflow depends on consistency state being persisted.
- On Windows PowerShell, REST requests with non-ASCII project paths can be fragile. Use `prepare-write-session` and then reuse the returned `BridgeProjectPath` for REST calls when needed.
- If `probe` or `doctor` shows `ReadyForOpennessSession = false`, stop before clone/import/compile and recover the session prerequisites first.

## References

- Generic workflow: `references/workflow.md`
- Project onboarding: `references/project-onboarding.md`
- Release workflow: `references/release-workflow.md`
- Version and routing: `references/version-routing.md`
- Version compatibility: `references/version-compatibility-v16-v21.md`
- LAD and template library: `references/lad-and-templates.md`
- Knowledge retrieval: `references/knowledge-retrieval.md`
- Classic control patterns: `references/classic-control-patterns.md`
- Ecosystem and next routes: `references/ecosystem-and-next-routes.md`
- Official Openness sources: `references/official-openness-sources.md`
- Official instruction-family sources: `references/official-instruction-sources.md`
- Instruction routing: `references/instruction-routing.md`
- Community Openness notes: `references/community-openness-notes-cnblogs-aifen.md`
- REST bridge: `references/rest-bridge.md`
- VS Code client template: `references/vscode-client-template.md`
- GUI download bridge: `references/gui-download-bridge.md`
- AI workflow configuration: `references/ai-workflow-config.md`
- Agent workbench: `references/agent-workbench.md`
- Advanced PLC automation: `references/advanced-plc-automation.md`
