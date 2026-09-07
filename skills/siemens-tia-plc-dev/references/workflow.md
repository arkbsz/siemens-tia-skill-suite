# Workflow

Use this when the task is about Siemens PLC development in general rather than one specific project.

## Standard loop

1. Back up the project.
2. Probe the local environment and stop there if `ReadyForOpennessSession` is `false`.
3. Build or refresh `PLC_Code`.
4. Export target blocks.
5. Summarize and inspect.
6. Edit or generate.
7. Validate XML or source structure.
8. Preview import.
9. Apply to a backup project.
10. Compile and save.
11. Re-export to confirm the intended change landed.

## Typical commands on this machine

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\bootstrap-siemens-plc-dev.ps1" -ProjectPath "D:\path\to\project"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\refresh-plc-libraries.ps1" -ProjectPath "D:\path\to\project"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" route-info
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" console -ProjectPath "D:\path\to\project" -Background
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" doctor -ProjectPath "D:\path\to\project"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" read-cycle -ProjectPath "D:\path\to\project" -UseUi
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" clone-project -ProjectPath "D:\path\to\project"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" prepare-write-session -ProjectPath "D:\path\to\project"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" export-blocks --project "D:\path\to\project" --language LAD --output "D:\path\to\project\PLC_Code\exports\lad"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" verify-lad-change -ProjectPath "D:\path\to\project" -InputXml "D:\path\to\project\PLC_Code\changes\my-change\outputs\my-change.generated.xml" -PlcName "PLC_1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" write-cycle -ProjectPath "D:\path\to\project" -InputXml "D:\path\to\project\PLC_Code\changes\my-change\outputs\my-change.generated.xml" -PlcName "PLC_1"
```

## Openness readiness gate

For live TIA reads or writes, treat `probe` or `doctor` as a hard gate:

- if `ConfiguredInSiemensTiaOpennessGroup` is `false`, add the user to the local Windows group first
- if `ActiveInCurrentLogonToken` is `false`, a new console is not enough; fully sign out of Windows and sign in again
- if `ReadyForOpennessSession` is `false`, do not start clone/import/compile loops yet

When the session gate is closed, keep moving with source-only LAD XML, SCL, summaries, templates, and release-package preparation instead of waiting on a stuck Openness run.

If a live command fails with `EngineeringSecurityException`, `Security error`, or a timeout immediately after a fresh install, treat it as a first-run Openness trust handshake problem. Run the same read once with `-UseUi` or open the project manually in TIA Portal and rerun with `-Attach`; do not keep retrying no-UI commands.

## Visual console entry point

Use `console` when the workflow needs a window instead of only terminal commands:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" console -ProjectPath "D:\path\to\project" -Background
```

The console provides project tree browsing, run/log preview, buttons for common Openness workflows, a `write-cycle` input box for generated LAD XML, and an AI task composer that saves context-rich Codex prompts under `PLC_Code\ai-prompts`.

## Read-cycle entry point

Use `read-cycle` when starting work on any existing project:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" read-cycle -ProjectPath "D:\path\to\project" -UseUi
```

It performs the standard read-first pass:

- probe Openness readiness
- list PLCs and pick the first PLC when `-PlcName` is omitted
- list blocks
- export LAD, FBD, and SCL blocks
- summarize exported LAD XML into Markdown
- build a LAD template catalog
- write logs and `workflow-report.json` under `PLC_Code\runs\<timestamp>`

Use `-UseUi` for the first run after installing TIA/Openness. Use `-Attach` when the project is already open in TIA Portal. Use `-SkipExport` when you only want readiness, PLC list, and block list.

## Two working modes

### 1. Live project automation

Use this when you need the project tree, export, import, or compile:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" list-plcs --project "D:\path\to\project"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" clone-project -ProjectPath "D:\path\to\project"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" compile-plc --project "D:\path\to\backup-project" --plc "PLC_1" --save
```

If the client should stay decoupled from direct TIA assembly loading, use the local REST bridge in `references/rest-bridge.md`.

### 2. Code-like LAD package flow

Use this when you want one ladder change to feel like an ordinary source edit with inputs, outputs, and review files:

Keep network titles short, keep signal names human-readable, and add one comment per behavior step.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" scaffold-lad-change -ProjectPath "D:\path\to\project" -SourceXml "D:\path\to\block.xml" -ChangeName "alarm-cleanup"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" patch-lad-network -TargetXml "D:\path\to\project\PLC_Code\changes\alarm-cleanup\outputs\alarm-cleanup.generated.xml" -DonorXml "D:\path\to\library\reuse.xml" -OutputXml "D:\path\to\project\PLC_Code\changes\alarm-cleanup\outputs\alarm-cleanup.generated.xml" -TargetNetworkIndex 3 -DonorNetworkIndex 1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" write-cycle -ProjectPath "D:\path\to\project" -InputXml "D:\path\to\project\PLC_Code\changes\alarm-cleanup\outputs\alarm-cleanup.generated.xml" -PlcName "PLC_1" -ReleaseName "alarm-cleanup"
```

`write-cycle` runs clone import, compile, post-import export, readable LAD summary, and release-package preparation as one safe gate. It does not modify the production project. If compile fails, it keeps the verification folder and logs but skips release packaging.

During long write verification, check `PLC_Code\runs\write-cycle-*\current-step.json` for the active stage. The child PowerShell process writes live stdout/stderr temp logs under `logs`, so inspect those files before assuming the workflow is stuck. Use `-StepTimeoutSeconds <n>` when a site needs a stricter no-hang limit.

For interactive import and export loops through REST, call `prepare-write-session` first. If the returned JSON contains a different `BridgeProjectPath`, use that path in later REST requests on Windows PowerShell.

## Routing

- Use Openness when you need live project reads, exports, imports, or compile.
- Use exported XML when you need diffable LAD/FBD logic.
- Use template manifests when you want reusable network patterns.
- Use SCL when the logic is algorithmic rather than maintenance-facing.
- Use GUI only when no structured route can reach the target.

## Source-backed project growth

For larger sample cells or reusable machine modules, the most stable route is:

1. define `UDT` interfaces first
2. add `FB` or `FC` source blocks next
3. add global and instance `DB` sources after the structural sources
4. compile and save on a cloned project before applying to the main project

When a source import tool generates many external sources in one run, do not rely on filesystem enumeration order. Sort structural sources by declared-object dependencies first:

- `UDT` before any source that references the type
- helper `FB` or `FC` before parent blocks that instantiate them
- `OB1` or other orchestration blocks after the blocks and interfaces they call
- global and instance `DB` sources after the structural sources they depend on

If `OB1` or another block references new `DB` sources that are still pending in the same import batch, skip the intermediate compile after structural-source generation. Compile after the `DB` sources are generated so the first compile result reflects the whole batch instead of expected temporary missing-tag errors.

On this Windows machine, if a local Openness helper project fails to build because `.NETFramework,Version=v4.8` reference assemblies are missing but `v4.8.1` is installed, retargeting that helper to `v4.8.1` is a practical local fix.
