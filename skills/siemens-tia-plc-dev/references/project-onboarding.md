# Project Onboarding

Use this when starting a new Siemens TIA project with this skill.

## First-hour workflow

1. Back up the project.
2. Probe the local TIA environment.
3. Build `PLC_Code`.
4. List PLCs and blocks.
5. Export the first target blocks.
6. Generate summaries before editing.

## Core commands

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" backup-project -ProjectPath "D:\path\to\project"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" bootstrap -ProjectPath "D:\path\to\project"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" list-plcs --project "D:\path\to\project"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" list-blocks --project "D:\path\to\project" --plc "PLC_1"
```

## Default engineering rule

Prefer:

- one block change at a time
- one change package per engineering intent
- one release package per validated result

This keeps later projects reviewable and reusable.
