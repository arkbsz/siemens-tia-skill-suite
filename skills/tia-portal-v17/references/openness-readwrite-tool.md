# Openness Read/Write Tool

Use this reference when building or running a local helper that reads and writes PLC code through TIA Portal Openness.

## What the helper should do

Verified local commands:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\tia-portal-v17\scripts\invoke-tia-openness.ps1" list-plcs --project "D:\path\to\project"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\tia-portal-v17\scripts\invoke-tia-openness.ps1" list-blocks --project "D:\path\to\project" [--plc "PLC_1"]
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\tia-portal-v17\scripts\invoke-tia-openness.ps1" export-blocks --project "D:\path\to\project" --language LAD --output "D:\path\to\project\PLC_Code\exports\lad"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\tia-portal-v17\scripts\invoke-tia-openness.ps1" import-blocks --project "D:\path\to\project" --input "D:\path\to\edited.xml" --plc "PLC_1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\tia-portal-v17\scripts\invoke-tia-openness.ps1" import-blocks --project "D:\path\to\project" --input "D:\path\to\edited.xml" --plc "PLC_1" --apply
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\tia-portal-v17\scripts\invoke-tia-openness.ps1" compile-plc --project "D:\path\to\project" --plc "PLC_1"
```

`import-blocks` is dry-run by default. Add `--apply` only after backup and review. Use `--ui` if TIA needs a visible prompt, or `--attach` after opening TIA manually.

## Read/write API anchors

For PLC software access:

```csharp
SoftwareContainer sc = deviceItem.GetService<SoftwareContainer>();
PlcSoftware plcSoftware = sc?.Software as PlcSoftware;
```

For regular block XML export/import on V17:

```csharp
plcBlock.Export(new FileInfo(outputXml), ExportOptions.WithDefaults);
plcSoftware.BlockGroup.Blocks.Import(
    new FileInfo(inputXml),
    ImportOptions.Override,
    SWImportOptions.IgnoreMissingReferencedObjects |
    SWImportOptions.IgnoreStructuralChanges |
    SWImportOptions.IgnoreUnitAttributes);
```

V17 reflection on this machine exposes `PlcBlock.Export(...)` and `PlcBlockComposition.Import(...)`. Do not assume `ExportAsDocuments(...)` or `ImportFromDocuments(...)` exists on this installation unless reflection confirms it.

For UDT export/import:

```csharp
plcSoftware.TypeGroup.Types.Import(new FileInfo(inputXml), ImportOptions.Override);
```

## Version notes

This machine has TIA Portal V17. V21 examples use modular assemblies; V17 commonly exposes `Siemens.Engineering.dll` plus related domain assemblies. Probe local DLLs before compiling helpers.

## Failure handling

If Openness attach/open fails:

- check the `Siemens TIA Openness` Windows group
- close extra TIA sessions
- set `TiaPortalLocation` user environment variable if a resolver expects it
- fall back to MCP or source-only workflow

If a command starts TIA but appears stuck, stop that attempt and switch route:

- run without parallel TIA Openness commands
- add `--ui` for visible prompts
- open TIA manually and use `--attach`
- avoid waiting indefinitely on a silent website, clone, or GUI session

## Write policy

Writes should be two-phase:

1. Preview target, input files, import mode, and expected affected blocks.
2. Apply only after backup and explicit confirmation.

Inside Codex, do not silently import or override blocks in a production project.
