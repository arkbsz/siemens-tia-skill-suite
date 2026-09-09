# TIA Portal Version Compatibility: V16-V21

This note captures the version differences that matter most for the packaged Siemens skill suite.

## Supported scope

- project files: `.ap16` through `.ap21`
- Openness routing: `V16` through `V21`
- XML/LAD offline workflow: `V16` through `V21`
- SIMATIC SD document workflow:
  - `V16-V19`: not a primary route in this package
  - `V20`: available for the first text-based graphical-document workflows
  - `V21`: expanded and preferred when the installed toolchain supports it

## Practical differences by version

### V16

- classic monolithic Openness layout under `PublicAPI\V16`
- main compile-time assembly is typically `Siemens.Engineering.dll`
- project extension is `.ap16`
- use exported XML and LAD/FBD graph artifacts as the default code-like surface
- treat newer SIMATIC SD document workflows as unavailable unless a target installation proves otherwise

### V17

- classic monolithic Openness layout under `PublicAPI\V17`
- main compile-time assembly is typically `Siemens.Engineering.dll`
- project extension is `.ap17`
- use exported XML and LAD/FBD graph artifacts as the default code-like surface

### V18

- still uses the classic monolithic assembly layout
- SimaticML handling becomes stricter, especially around required `namespace` attributes
- extra Openness-side validation and product checks matter more during import/export automation

### V19

- still uses the classic monolithic assembly layout
- adds `NamedValueConstant` / named value type coverage in SimaticML
- some legacy engineering-side automations changed or were removed, so old tooling assumptions must be rechecked

### V20

- still uses the classic monolithic assembly layout
- introduces `SIMATIC SD` as a text-based exchange route for graphical programming workflows
- rename validation for PLC tags and constants becomes stricter
- keep XML as the safe fallback when document import/export is not confirmed on the target installation

### V21

- switches to modular Openness assemblies under `PublicAPI\V21\net48`
- build against `Siemens.Engineering.Base.dll` plus `Siemens.Engineering.Step7.dll`
- expands document workflows beyond the earlier `V20` scope
- official docs state that `SimaticML` import is supported for files exported from `V18` through `V21`

## How the packaged skill routes across versions

1. Detect project version from `.ap16` to `.ap21` when possible.
2. Resolve the matching local TIA installation and `PublicAPI` root.
3. Use `V21` modular references only when the resolved environment is `V21`.
4. Use XML/LAD fallback when document-style import/export is unavailable or unverified.
5. Fail early if the project version and installed Openness environment do not match.

## Implementation rules

- prefer `invoke-siemens-plc-dev.ps1 doctor` before any live write workflow
- prefer exact-version local installs for `.ap16` through `.ap21` projects
- do not assume `V21` can safely replace every older live workflow without an intentional migration step
- for LAD authoring, keep exported XML as the stable reviewable surface across all supported versions
- treat `SIMATIC SD` as an additive route, not a replacement for XML validation

## Code-Like Editing Strategy

- `V16-V19`: default to Openness XML export/import for LAD/FBD and SCL source import for text blocks. Build repeatable edits around exported block XML, `NetworkSource` / `FlgNet` donor networks, and clone compile readback.
- `V20`: allow SIMATIC SD/document workflows when the exact installation exports the required object type; keep XML as fallback.
- `V21`: prefer SIMATIC SD when available for code-like source control and bulk text edits across LAD/FBD/SCL/DB/UDT, then still validate by import/compile/readback through Openness.

The workbench should expose these routes as choices, but automatic mode should pick the oldest reliable route first unless the project version and installed API prove a newer document route is available.

## Source Anchors

- Siemens Openness overview, Entry ID `109792902`
- Siemens official Openness snippets: `https://github.com/siemens/tia-portal-openness-code-snippets`
- SIMATIC SD for TIA Portal: `https://github.com/siemens/simatic-sd`
- Siemens TIA Portal V21 programming guideline: `https://support.industry.siemens.com/cs/document/109974823`
