---
name: siemens-wincc-hmi-dev
description: "Use for Siemens WinCC HMI automation in TIA Portal when creating or refactoring screens, tags, alarms, faceplates, navigation, SiVArc rules, or WinCC Unified runtime workflows. Do not use for pure PLC block logic or generic UI design."
---

# Siemens WinCC HMI Dev

Use this skill when the task is HMI/WinCC-specific rather than PLC-only.

Prefer these routes:

- TIA Portal Openness for HMI project traversal, screen/tag/alarm editing, and export/import style work
- SiVArc Openness for rule-based generation of WinCC content
- WinCC Unified GraphQL or Open Pipe when the task is runtime read/write/subscribe against a Unified runtime
- visual AI routing for text-to-image or image-to-image screen concepts, then conversion into WinCC-native components
- plugin-aware routing that detects the TIA version and locally available imagegen, Openness, SiVArc, TIA MCP, screen-script export, and Unified runtime MCP adapters
- clone-first Agent queue execution when a screen task spans visual analysis, component selection, tag contract updates, Openness/SiVArc engineering, runtime validation, and safety review

## Screen quality target

Treat HMI work as an operator workstation design task, not just a tag binding task.

For new or refactored screens:

- start from a screen map: Overview, Manual, Automatic, Alarm, Trend, Parameter, Maintenance, and Diagnostics
- put equipment state, mode, interlocks, faults, and current step in the first scanning area
- keep navigation stable across screens and reserve one consistent alarm/status strip
- group controls by physical station or process flow instead of by PLC block order
- use a restrained industrial palette with clear state colors: normal, running, warning, fault, disabled, and manual override
- make command buttons visually distinct from indicators and require confirmation for reset, homing, recipe write, or force-like actions
- keep tag names, faceplate names, and screen object names aligned with PLC DB/UDT contracts
- add comments or design notes for generated screens so future engineers know which PLC contract drives each area
- when a reference image is uploaded, analyze layout, palette, typography, component hierarchy, and state colors before choosing WinCC standard controls, faceplates, SiVArc rules, or custom components

Before any write-like action, back up the project or work on a clone.
When PLC and HMI data must align, stabilize the PLC tag/DB contract first, then mirror it in the HMI.
If the exact WinCC flavor or installed API version is unclear, inspect the local TIA installation before assuming a DLL or method exists.

For WinCC design tasks, run `scripts/resolve-wincc-plugins.ps1` before implementation. It refreshes vetted GitHub metadata when requested, writes `PLC_Code\wincc\plugin-routing.json`, and selects only compatible installed adapters. Use the generated invocation plan in the Codex task. Do not execute a downloaded prebuilt community binary until its source and provenance have been reviewed.

For reference-image or text-driven HMI design, scaffold a package before engineering writes:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" wincc-visual-package -ProjectPath "D:\path\to\project" -TaskText "Create a station overview screen"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" wincc-component-blueprints -ProjectPath "D:\path\to\project" -TaskText "Create reusable WinCC component blueprints"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" wincc-engineering-scaffold -ProjectPath "D:\path\to\project" -TaskText "Create clone-first WinCC engineering scaffold"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" wincc-openness-implementation -ProjectPath "D:\path\to\project" -ForCloneOnly
```

This writes `PLC_Code\wincc\tasks\latest\design-brief.md`, `screen-map.md`, `component-map.md`, `tag-contract.md`, `style-guide.md`, `implementation-plan.md`, and `safety-review.md`.

The current package also includes `reference-analysis.md`, `component-selection-matrix.md`, `component-candidates.json`, `plugin-invocation-plan.md`, `cwc-faceplate-package.md`, and `engineering-tasks.json`. Use these as the workbench-native handoff between visual design, component selection, Openness/SiVArc/CWC engineering and validation. The generated image or uploaded screenshot is a reference target only; final HMI content should remain editable WinCC objects wherever possible.

Run `wincc-component-blueprints` after the visual package when the screen must become a reusable project pattern. It writes `PLC_Code\wincc\component-blueprints\latest\component-blueprints.md/json`, `screen-layout-grid.json`, `sivarc-rule-blueprints.md`, and `cwc-package-manifest.json`. Use these files to map each visual zone to existing faceplates, standard WinCC controls, SiVArc repeated-object rules, custom faceplates, or CWC candidates before any write-like engineering step.

Run `wincc-engineering-scaffold` after the visual package and component blueprints when the design is ready to become engineering work. It writes `PLC_Code\wincc\engineering-scaffold\latest` with preflight checks, HMI tag and alarm import maps, Faceplate build lists, SiVArc generation checks, CWC review notes, Unified runtime smoke plans and clone-validation plans. This is the handoff from visual design into Openness/SiVArc/CWC implementation, not a direct production-screen write.

Run `wincc-openness-implementation` after `wincc-engineering-scaffold` when the scaffold should become a concrete implementation package. It writes `PLC_Code\wincc\openness-implementation\latest` with screen/object mapping, packaged HMI tag/alarm inputs, `WinccEngineeringSkeleton.cs`, `implementation-manifest.json`, and a runner that calls the real clone-only Openness implementation workflow.

The native workbench also exposes executable WinCC operations:

- `wincc-read-cycle` calls Openness to enumerate HMI targets and writes screen, tag, alarm, connection and export readback evidence under `PLC_Code\wincc\readback`.
- `wincc-apply-clone` preflights the HMI target, clones the project, applies the packaged manifest to a supported WinCC Unified target, reads the clone back, and writes `implementation-run.json`. It never writes the production project or downloads to a PLC.
- `read-hmi` and `import-hmi` provide direct Openness routes for Classic WinCC XML readback/import.

Classic WinCC screen/tag creation remains import-driven because the V17 object model exposes export/import compositions rather than a general-purpose `Create` method. The workflow must not report a Classic object as created unless the XML import and readback both succeed.

For larger WinCC work, generate an Agent plan and execution queue from the PLC skill, then run one stage at a time through `queue-run-current`. Keep the visual reference, component map, tag contract, generated assets, Openness/SiVArc scripts, runtime validation notes and safety review as separate evidence files so the workbench can review them like a local pull request.

Read `references/official-sources.md` for the capability boundaries, `references/workflow.md` for the recommended edit loop, `references/screen-design.md` for layout, navigation, and visual quality rules, `references/visual-ai-workflow.md` when the task uses text descriptions or uploaded reference images, `references/visual-to-wincc-pipeline.md` when the result must become editable WinCC objects, and `references/plugin-routing.md` when selecting or configuring WinCC plugins.
