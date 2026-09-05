# Official Openness Sources

Use these official sources as the baseline when implementing Siemens TIA Portal Openness tools.

## Primary sources

- Siemens support overview: `109792902`
- Siemens "Getting Started and Demo Application": `108716692`
- Siemens docs.tia page: `Requirements for TIA Portal Openness`
- Siemens docs.tia page: `Adding users to the 'Siemens TIA Openness' user group`
- Siemens official GitHub snippets: `siemens/tia-portal-openness-code-snippets`
- Siemens standard instruction manual: `1214574`
- Siemens programming guideline: `81318674`

## What they establish

- TIA Portal Openness is the official .NET API for engineering automation.
- TIA Portal `V16` through `V20` follow the classic monolithic assembly layout.
- TIA Portal `V21` changes to modular Openness assemblies under `PublicAPI\V21\net48`.
- The Windows user should be in the `Siemens TIA Openness` group.
- Siemens also documents the user-group setup as an explicit prerequisite and, in practice, the current Windows sign-in session must already contain that group before Openness automation will connect reliably.
- Applications typically reference:
  - `V16-V20`: `Siemens.Engineering.dll`
  - `V21`: `Siemens.Engineering.Base.dll` plus `Siemens.Engineering.Step7.dll`
- Siemens documents `SIMATIC SD` and `SimaticML` document workflows as version-sensitive features, so live write tooling should pick the route based on the detected TIA version.
- Siemens demonstrates patterns such as:
  - open or connect to TIA Portal
  - create or open a project
  - add devices
  - traverse the engineering object model
  - compile devices
- Siemens documents instruction families separately, which is a strong hint not to force every instruction into one direct LAD JSON encoding.
- The stable route is:
  - direct JSON for simple ladder parts
  - generic `CALL` for block-like instruction surfaces
  - SCL source import for algorithmic and data-heavy logic

For specific instruction-family references, also read `references/official-instruction-sources.md`.
For version differences that affect this skill suite, also read `references/version-compatibility-v16-v21.md`.

## Local implementation mapping

The current local implementation already uses these Openness patterns in:

- `%USERPROFILE%\.codex\skills\tia-portal-v17\scripts\TiaPlcTool.cs`
- `%USERPROFILE%\.codex\skills\siemens-tia-plc-dev\scripts\tia_rest_bridge.py`

For source-import helpers that you compile locally, two practical lessons were validated on this machine:

- import order matters; do not let file enumeration decide the generation order for dependent `UDT`, `FB`, `FC`, and `OB` sources
- if the machine has the `.NET Framework 4.8.1` targeting pack but not the `4.8` pack, target `v4.8.1` for local helper builds

To start a fresh official-style C# helper project, use:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\scaffold-openness-console.ps1" -TargetDirectory "D:\path\to\OpennessConsole" -ProjectName "MyTiaTool"
```
