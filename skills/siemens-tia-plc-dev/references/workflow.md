# Workflow

Use this when the task is about Siemens PLC development in general rather than one specific project.

## Standard loop

1. Back up the project.
2. Probe the local environment.
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
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" clone-project -ProjectPath "D:\path\to\project"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" prepare-write-session -ProjectPath "D:\path\to\project"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" export-blocks --project "D:\path\to\project" --language LAD --output "D:\path\to\project\PLC_Code\exports\lad"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" verify-lad-change -ProjectPath "D:\path\to\project" -InputXml "D:\path\to\project\PLC_Code\changes\my-change\outputs\my-change.generated.xml" -PlcName "PLC_1"
```

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
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" verify-lad-change -ProjectPath "D:\path\to\project" -InputXml "D:\path\to\project\PLC_Code\changes\alarm-cleanup\outputs\alarm-cleanup.generated.xml" -PlcName "PLC_1"
```

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
