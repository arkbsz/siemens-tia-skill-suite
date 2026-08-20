# Official Openness Sources

Use these official sources as the baseline when implementing Siemens TIA Portal Openness tools.

## Primary sources

- Siemens support overview: `109792902`
- Siemens "Getting Started and Demo Application": `108716692`
- Siemens official GitHub snippets: `siemens/tia-portal-openness-code-snippets`

## What they establish

- TIA Portal Openness is the official .NET API for engineering automation.
- TIA Portal V17 includes the Openness option package in the standard installation.
- The Windows user should be in the `Siemens TIA Openness` group.
- Applications typically reference `Siemens.Engineering.dll` from the local `PublicAPI\V17` folder.
- Siemens demonstrates patterns such as:
  - open or connect to TIA Portal
  - create or open a project
  - add devices
  - traverse the engineering object model
  - compile devices

## Local implementation mapping

The current local implementation already uses these Openness patterns in:

- `C:\Users\bsz\.codex\skills\tia-portal-v17\scripts\TiaPlcTool.cs`
- `C:\Users\bsz\.codex\skills\siemens-tia-plc-dev\scripts\tia_rest_bridge.py`

For source-import helpers that you compile locally, two practical lessons were validated on this machine:

- import order matters; do not let file enumeration decide the generation order for dependent `UDT`, `FB`, `FC`, and `OB` sources
- if the machine has the `.NET Framework 4.8.1` targeting pack but not the `4.8` pack, target `v4.8.1` for local helper builds

To start a fresh official-style C# helper project, use:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\scaffold-openness-console.ps1" -TargetDirectory "D:\path\to\OpennessConsole" -ProjectName "MyTiaTool"
```
