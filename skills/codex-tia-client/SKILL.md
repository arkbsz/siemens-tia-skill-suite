---
name: codex-tia-client
description: "Use when Codex itself should replace a separate Siemens PLC AI helper app and act as the main client for TIA Portal work: backup-first project reads, block export/import, LAD XML and LAD JSON editing, compile loops, and local REST bridge workflows."
---

# Codex TIA Client

Use this skill when the user wants Codex desktop to be the primary Siemens PLC client instead of a separate AI chat app.

Prefer this skill for:

- Codex-native PLC conversations
- direct use of local wrapper scripts from Codex
- project-local export, edit, import, compile loops
- LAD read/write through XML or JSON specs
- local REST bridge workflows when editor-side HTTP is preferred

This skill is a Codex-first entrypoint. It relies on the sibling skill `siemens-tia-plc-dev` for the underlying Openness and LAD tooling.

## First move

Before any write-like action:

1. back up the project
2. probe the local TIA route if the environment changed
3. export blocks into a text workspace

Use the wrapper:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\codex-tia-client\scripts\invoke-codex-tia-client.ps1" -ProjectPath "D:\path\to\project" backup
```

## Common commands

Project-level:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\codex-tia-client\scripts\invoke-codex-tia-client.ps1" -ProjectPath "D:\path\to\project" probe
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\codex-tia-client\scripts\invoke-codex-tia-client.ps1" -ProjectPath "D:\path\to\project" backup
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\codex-tia-client\scripts\invoke-codex-tia-client.ps1" -ProjectPath "D:\path\to\project" list-plcs
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\codex-tia-client\scripts\invoke-codex-tia-client.ps1" -ProjectPath "D:\path\to\project" list-blocks --plc "PLC_1"
```

Export and review:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\codex-tia-client\scripts\invoke-codex-tia-client.ps1" -ProjectPath "D:\path\to\project" export-lad --plc "PLC_1" --block "Main"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\codex-tia-client\scripts\invoke-codex-tia-client.ps1" -ProjectPath "D:\path\to\project" export-scl --plc "PLC_1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\codex-tia-client\scripts\invoke-codex-tia-client.ps1" summarize-lad -Path "D:\path\to\block.xml" -OutputPath "D:\path\to\block.summary.md"
```

LAD write path:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\codex-tia-client\scripts\invoke-codex-tia-client.ps1" scaffold-lad-json -OutputPath "D:\path\to\network.json" -Title "Alarm rung"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\codex-tia-client\scripts\invoke-codex-tia-client.ps1" write-lad-json -TargetXml "D:\path\to\block.xml" -SpecPath "D:\path\to\network.json" -OutputXml "D:\path\to\generated.xml" -NetworkIndex 1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\codex-tia-client\scripts\invoke-codex-tia-client.ps1" write-lad-batch -TargetXml "D:\path\to\block.xml" -ManifestPath "D:\path\to\batch-manifest.json" -OutputXml "D:\path\to\generated.xml"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\codex-tia-client\scripts\invoke-codex-tia-client.ps1" -ProjectPath "D:\path\to\project" import-blocks --input "D:\path\to\generated.xml" --plc "PLC_1" --apply
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\codex-tia-client\scripts\invoke-codex-tia-client.ps1" -ProjectPath "D:\path\to\project" compile --plc "PLC_1" --save
```

Batch manifests use this shape:

```json
{
  "steps": [
    { "networkIndex": 7, "specPath": "D:\\path\\to\\network07.json" },
    { "networkIndex": 8, "specPath": "D:\\path\\to\\network08.json" }
  ]
}
```

REST bridge:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\codex-tia-client\scripts\invoke-codex-tia-client.ps1" bridge-start
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\codex-tia-client\scripts\invoke-codex-tia-client.ps1" -ProjectPath "D:\path\to\project" session
```

## Project-local shortcut

If the current PLC project contains:

`.\.codex\codex-tia-project.ps1`

prefer that local wrapper. It pins the project path automatically so Codex can work like a normal code client inside that project.

## Guardrails

- Keep backup-first behavior.
- Prefer exported XML or source over blind binary edits.
- For non-ASCII project paths, use the write-session helper and reuse `BridgeProjectPath` when REST calls get brittle.
- Treat compile on clone or backup copy as the validation gate for new LAD write patterns.
- If the user says to replace an external AI helper app, stay inside Codex and local scripts unless a GUI-only action is truly required.
