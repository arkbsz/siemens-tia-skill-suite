# Agent Workbench

Use this reference when the goal is to make the native workbench behave like a PLC-focused agent application instead of a thin launcher for another AI client.

## Target Shape

The workbench should own the PLC automation loop:

- project context: detect the open TIA project, load `PLC_Code`, show exported blocks, DBs, HMI assets, logs and run reports
- task intake: accept text, image and document attachments, then save them into the project workspace
- route planning: create `PLC_Code\agent-plans\latest-plan.md` before large edits
- execution: call the selected local agent platform, Openness helper, WinCC plugin resolver and LAD/SCL/DB generators
- review: show generated files, diffs, logs, compile results and risk notes inside the workbench
- persistence: save project-level settings in `PLC_Code\config\ai-workflow.json`
- queue: convert approved plans into stage prompts, command suggestions, logs and evidence folders under `PLC_Code\agent-queues`
- capability map: keep an honest editor-replacement matrix under `PLC_Code\workbench\capabilities\latest`

The workbench can use Codex, Claude Code, Trae Agent or Qoder as execution engines, but the user-facing workflow should remain inside `PLCDevConsole.exe`.

## Planning Gate

For any task that affects more than one block, DB, HMI screen, technology object, communication block or safety behavior, generate a plan first:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" agent-plan -ProjectPath "D:\path\to\project" -TaskText "task" -Workflow agent-workbench
```

The plan must include:

- context-read stage
- knowledge-retrieval stage
- PLC contract stage when DB, tags or logic are involved
- LAD/SCL/advanced-instruction stage as appropriate
- WinCC intake, visual reference and component decomposition stages for HMI work
- compile, simulation or runtime validation stage
- safety-risk stage when commands, motion, faults or HMI writes are involved
- release stage that keeps production write separate

## Workbench Parity With AI Clients

The workbench should gradually absorb these common coding-agent features:

- persistent conversations and compatible session IDs per platform
- model, provider, sandbox and search controls
- file upload and image attachment routing
- project tree and file preview
- command output and stderr capture
- task plan generation
- task execution queue generation through `agent-queue`
- queue stage state transitions through `queue-stage`
- one-click current queue stage execution through `queue-run-current`
- project object-model and Agent-context generation through `project-model`
- one-click first-pass development orchestration through `agent-pipeline`
- editor-replacement capability mapping through `capability-map`
- workbench dashboard panels through `workbench-dashboard`
- WinCC Openness implementation packages through `wincc-openness-implementation`
- simulation scenario replay evidence through `simulation-replay`
- structured PLC change packages with DB contracts, LAD JSON, SCL source folders, import manifests, validation plans and risk notes
- local PR-style review packages through `review-package`
- editable preview for exported text artifacts with automatic backup-on-save
- readable LAD XML preview inside the workbench
- generated prompt files for audit
- run history and reports
- source diffs and release-package review
- stop/new-session controls

Do not claim full parity until the workbench also has explicit approval checkpoints and richer block-aware editors. One-click stage execution is available through `queue-run-current`; diff and validation panels are fed by `workbench-dashboard`, but the workbench still uses exported artifacts and review gates instead of editing TIA binary storage directly.

## Implementation Priorities

1. Prefer commands routed through `invoke-siemens-plc-dev.ps1` so every feature is scriptable outside the UI.
2. Store every generated artifact under `PLC_Code` so another agent or engineer can inspect it.
3. Add UI controls only when they write to a real config field or execute a real command.
4. Use `plc-change-package` for real PLC edits so LAD/SCL/DB changes, import manifest, validation and safety notes stay together.
5. Use `agent-queue` to turn large plans into stage prompts and gate records before multi-block PLC/WinCC work.
6. Use `queue-stage` for one-stage-at-a-time state transitions so the workbench always has a current prompt, suggested command and gate.
7. Use `queue-run-current` to execute the active stage through the configured Agent platform while recording stdout, stderr, metadata and evidence under `PLC_Code\agent-queues\latest`.
8. Use `project-model` to build `PLC_Code\workbench\context\latest\agent-context.md`, `project-model.json`, and `file-index.csv` before broad edits or cross-platform Agent execution.
9. Use `knowledge-pack` to bind official-first documentation, current project evidence and reviewed community routes into the Agent context before authoring.
10. Use `capability-map` to show which editor-like features are ready, partial, gated or still TIA-native before claiming replacement coverage.
11. Use `wincc-engineering-scaffold` after the visual package and component blueprints when a WinCC task must turn into engineering work.
12. Use `wincc-openness-implementation` after the WinCC engineering scaffold when a screen/tag/alarm design must become a reviewed, executable clone-only Openness implementation package; the runner must call the local helper, not stop at a generated C# placeholder.
13. Use `simulation-package` whenever a broad PLC/WinCC task needs validation beyond static generation.
14. Use `simulation-replay` after `simulation-package` when the workbench needs scenario-by-scenario evidence readiness for clone compile, project-model I/O mapping, PLCSIM Advanced and WinCC Unified runtime smoke.
15. Use `agent-pipeline` for the first pass of a broad user request: it classifies PLC/WinCC scope, creates project context, knowledge, capability mapping, instruction routing, WinCC visual packages, WinCC engineering scaffold, WinCC Openness implementation package, simulation package, simulation replay evidence, an Agent plan, an execution queue and a dashboard without production writes.
16. Use `workbench-dashboard` to refresh queue health, latest run reports, import readiness, project context, plugin routing, instruction routes, safety risks, WinCC engineering tasks, WinCC implementation packages, simulation packages, replay evidence, capability gaps and Git diff summaries into the native validation and diff panels.
17. Use `review-package` before release to collect artifact hashes, diff evidence, readiness flags and safety gates.
18. Keep production project writes behind the existing backup, clone compile and explicit release gates.
19. If a remote page, CLI or TIA session stalls, capture the partial log and switch route instead of blocking the whole workbench.

## One-Click Development Pipeline

`agent-pipeline` is the workbench's default entry when the user describes a broad PLC/WinCC automation task and expects the local app to behave like an Agent IDE:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" agent-pipeline -ProjectPath "D:\path\to\project" -TaskText "task" -RefreshWinccCatalog
```

It runs only planning and package-generation steps:

- Always first: generate `PLC_Code\workbench\context\latest` with the project object model, latest artifacts, block table, route preference, and file index.
- Next: generate `PLC_Code\knowledge\packs\latest` and `PLC_Code\workbench\capabilities\latest` so Agents see both source evidence and current workbench limits.
- PLC task detected: generate `PLC_Code\plc\instruction-plans\latest` with instruction-family routing, technology-object checks and safety-risk notes.
- WinCC task detected: refresh plugin routing, then generate `PLC_Code\wincc\tasks\latest` with reference analysis, screen map, component map, tag contract, component-selection matrix, implementation plan and safety review.
- WinCC task detected after component blueprints: generate `PLC_Code\wincc\engineering-scaffold\latest` so screen/tag/alarm/faceplate/SiVArc/CWC work is split into reviewable engineering tasks.
- WinCC task detected after the engineering scaffold: generate `PLC_Code\wincc\openness-implementation\latest` so screen/object mapping and clone-only Openness implementation inputs are visible before release.
- All broad tasks: generate `PLC_Code\simulation\latest` and `PLC_Code\simulation\replays\latest` so static validation, scenario evidence, clone compile, readback, PLCSIM Advanced hooks and WinCC runtime smoke checks are visible before release.
- All tasks: generate `PLC_Code\agent-plans\latest-plan.md`, `PLC_Code\agent-queues\latest\queue.md` and `PLC_Code\workbench\latest\dashboard.md`.

After this first pass, run or review one queue stage at a time. Do not let `agent-pipeline` import blocks, write HMI screens or download to PLC; those remain separate clone-verified release actions.

## Queue State Machine

The queue is stored at `PLC_Code\agent-queues\latest\queue.json`.

- `start-next`: marks the next pending stage as `IN_PROGRESS` and writes `current-stage.md/json`.
- `record-current`: keeps the active stage `IN_PROGRESS` while attaching new evidence or notes from an Agent run.
- `complete-current`: marks the active stage as `DONE`.
- `fail-current`: marks the active stage as `FAILED` and keeps evidence for diagnosis.
- `block-current`: marks the active stage as `BLOCKED` when a real external prerequisite is missing.
- `reset`: returns all stages to `PENDING`.

The workbench should execute or present only one stage at a time. A stage may call an Agent, a script, Openness, WinCC plugin routing, clone compile, or human review, but its artifact and gate evidence should be recorded before moving on.

`queue-run-current` is the default workbench execution action:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" queue-run-current -ProjectPath "D:\path\to\project" -RoutingMode auto -Platform auto -Sandbox workspace-write -Search
```

It starts the next pending stage when no stage is active, passes the current stage prompt to `invoke-ai-platform-agent.ps1`, captures the platform JSONL and stderr logs, writes `stage-run.json` and `stage-run.md`, and records the evidence path back into the queue. By default a successful run stays `IN_PROGRESS` for review; use `-CompleteOnSuccess` only for read-only stages with a clear automatic gate.

## Review Package

`review-package` creates `PLC_Code\review-packages\latest` with:

- `review-summary.md`
- `artifact-index.json`
- `artifact-index.csv`
- optional `git-diff.patch`
- `import-readiness.json`
- `logs`
- `evidence`

Use this package as a local PLC/WinCC pull request before import, compile, release, or GitHub sync.

## Dashboard Panels

`workbench-dashboard` writes `PLC_Code\workbench\latest\dashboard.md`, `validation-summary.md`, `diff-summary.patch`, and `dashboard.json`.

The native workbench uses these files to populate:

- `任务编排`: current plan, queue and route overview.
- `审查/Diff`: project-local Git diff or a clear note when no diff is available.
- `验证面板`: queue health, latest read/write run reports, import readiness, WinCC engineering scaffold, simulation package and safety gates.
- `项目模型`: the latest `agent-context.md` plus a JSON preview of `project-model.json`.

Run it after any substantial Agent, read-cycle, write-cycle, WinCC visual package or review-package action so the window reflects current evidence rather than stale logs.

## Capability Map

`capability-map` creates `PLC_Code\workbench\capabilities\latest\capability-map.md/json`.

Use it when the goal is to move from a launcher toward an editor-like Agent application. Each row must name the UI entry, script command, generated artifacts, validation gate, remaining native TIA dependency and next step. A capability is not considered fully ready merely because a button exists; it needs a scriptable command, inspectable output and a verification path.

## Project Object Model

`project-model` creates the workbench's fast context bundle:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" project-model -ProjectPath "D:\path\to\project" -TaskText "task"
```

It intentionally indexes only current engineering artifacts instead of recursively scanning bulky release or backup folders. Agent stages should read `PLC_Code\workbench\context\latest\agent-context.md` first, then use `project-model.json` when they need machine-readable block, file, artifact and version routing data.

## Editor-Replacement Boundary

The workbench may replace day-to-day editing for exported PLC/HMI artifacts when it can show the file, save with backup, generate a change package, create a plan, create an execution queue and run validation scripts. It must not edit TIA project binary storage directly.

For `V16-V19`, treat Openness XML/SCL exports and donor LAD networks as the stable code surface. For `V20-V21`, prefer SIMATIC SD/document-style exports when the installed TIA version supports the requested block type, while keeping XML import/export as the fallback and verification surface.

The mature loop is:

1. read project and exports
2. create or update contract
3. generate source/XML/LAD JSON/WinCC package
4. run clone compile or runtime smoke test
5. re-export and compare
6. prepare release, then wait for explicit production-apply intent

## Useful External Patterns

- Siemens Openness: project traversal, import/export and compile automation.
- Siemens SiVArc: rule-based HMI generation from PLC structures and templates.
- WinCC Unified GraphQL: runtime read/write/subscribe validation for trusted Unified endpoints.
- Custom Web Controls: use when standard controls and faceplates cannot reproduce a required HMI widget.
- Community LAD/MCP/Openness tools: useful as adapters after source/provenance review, not as blind binary dependencies. The reusable pattern is real export, structural inspection, small patch, import on clone, compile, readback and only then save or release.

Source anchors:

- `https://github.com/siemens/tia-portal-openness-code-snippets`
- `https://github.com/ActionUnity/tia-v18-lad-agent`
- `https://github.com/eponce00/tiaopen-mcp`
- `https://github.com/bulaofen0036-coder/TIA_Portal_Openness_MCP`
