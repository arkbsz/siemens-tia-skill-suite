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

## Native visual console

Use the local visual console when the user wants a better interaction surface than terminal commands. The default `console` command builds and opens a native Windows Forms `PLCDevConsole.exe` window with:

- automatic current-TIA-project detection plus browse/open actions for `.ap16` through `.ap21`
- a draggable left project tree for TIA projects, exported XML/SCL/DB/UDT, reports, and logs
- switchable center pages for AI chat, command logs, file preview, and runs
- a bottom AI task box with model/workflow selection and configurable Windows-font UI settings
- visual WinCC task controls for API provider, image workflow, image model, quality, size, component strategy, and uploaded reference image preview
- common workflow buttons for `doctor`, `read-cycle`, `list-blocks`, and `write-cycle`
- run and log preview panels for `PLC_Code\runs` and `PLC_Code\console-jobs`
- a Codex-ready prompt file writer under `PLC_Code\ai-prompts`

Start it with:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" console -ProjectPath "D:\path\to\project"
```

Use `console-exe` explicitly when you want the native executable route, or `console-web` only as a fallback browser-based console. The first native version keeps the AI panel as a Codex task composer rather than a hidden cloud agent. Use the generated prompt file in the main Codex thread for code generation, LAD review, and safe write-cycle execution.

## Local bridge

This release keeps the legacy sibling skill name `tia-portal-v17`, but the packaged bridge now routes TIA Portal `V16` through `V21`.

Use the wrapper scripts in this skill to stay generic:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\bootstrap-siemens-plc-dev.ps1" -ProjectPath "D:\path\to\project"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\refresh-plc-libraries.ps1" -ProjectPath "D:\path\to\project"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" console -ProjectPath "D:\path\to\project"
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

For a generated LAD XML block, prefer `write-cycle` as the safe default before any real import. It verifies the block on a cloned project, compiles, re-exports, writes a readable summary, and prepares a release package only when compile succeeds. It does not write directly to the production project.

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
