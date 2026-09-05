# __PROJECT_NAME__

This is a minimal Siemens TIA Portal Openness console project scaffolded from the local skill.

## Purpose

It demonstrates the official Openness programming style for:

- opening a TIA project
- traversing devices to find PLC software
- listing blocks
- compiling PLC software

## Build notes

- Target framework: `.NET Framework 4.8`
- Platform: `x64`
- Main Siemens dependency:
  - `V16-V20`: `Siemens.Engineering.dll`
  - `V21`: `Siemens.Engineering.Base.dll` plus `Siemens.Engineering.Step7.dll`
- Default TIA root: `C:\Program Files\Siemens\Automation\Portal V16`
- Override `TiaPortalVersionMajor`, `TiaPortalRoot`, or `TiaPortalPublicApiRoot` when targeting `V17` through `V21`.
- If build shows `MSB3644`, install the `.NET Framework 4.8 Developer Pack` or `Targeting Pack` to remove the warning.
- Do not open the same TIA project from multiple Openness processes at the same time. TIA project locking will block the second open.

If your TIA installation is somewhere else, set the environment variable `TiaPortalLocation`, `CODEX_TIA_PREFERRED_VERSION`, or override the `TiaPortalRoot` / `TiaPortalPublicApiRoot` MSBuild properties.

## Example commands

```powershell
__PROJECT_NAME__.exe list-plcs --project "D:\path\to\project.ap16"
__PROJECT_NAME__.exe list-blocks --project "D:\path\to\project.ap20" --plc "PLC_1"
__PROJECT_NAME__.exe compile-plc --project "D:\path\to\project.ap21" --plc "PLC_1" --save
```

## Why use this

Use this scaffold when you want your own Openness-based helper program instead of only relying on the generic REST bridge or the existing local scripts.
