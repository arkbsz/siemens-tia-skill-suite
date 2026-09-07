# Changelog

## Unreleased

- Extended the packaged Openness bridge from a V17-only assumption to version-aware routing across TIA Portal V16 through V21.
- Added shared TIA version resolution, `.ap17` through `.ap21` project detection, and V21 modular assembly handling for helper builds and scaffolds.
- Added a version-compatibility reference that captures the V16-V21 differences most relevant to Openness, XML, and SIMATIC SD workflows.
- Expanded the WinCC HMI skill with screen hierarchy, navigation, visual consistency, and alarm/diagnostic layout guidance.
- Added `siemens-wincc-hmi-dev` for WinCC HMI automation workflows.
- Updated the release package metadata and installer to include the WinCC skill.
- Expanded `siemens-tia-plc-dev` with instruction-routing guidance so most Siemens instruction families can be routed through LAD JSON, generic `CALL`, SCL source import, or donor-network patching.
- Added direct LAD JSON generation support for `TOF`, `TP`, `CTD`, and `CTUD`, plus new reusable example specs.
- Updated `summarize-lad-xml.ps1` to read back `TOF`, `TP`, `CTD`, and `CTUD` networks into human-readable summaries.
- Hardened the Openness workflow with structured readiness fields in `probe-tia-v17.ps1`, a `doctor` alias in the generic wrapper, and fail-fast preflight checks before live Openness commands or clone-based LAD verification.
- Added `read-cycle` as the standard project intake command for probe, PLC/block listing, LAD/FBD/SCL export, LAD summaries, template catalog, and workflow reports.
- Added `write-cycle` as the standard generated-LAD safety gate: clone verification, import, compile, post-import export, readable summary, and release-package preparation only after successful compile.
- Hardened `write-cycle` observability with `current-step.json`, stdout/stderr temp logs, and `-StepTimeoutSeconds` to avoid black-box live Openness waits.
- Added a native Windows Forms `PLCDevConsole.exe` workflow console with project tree browsing, run/log preview, common workflow buttons, generated LAD XML write-cycle entry, and a Codex-ready AI task composer.
- Kept the earlier browser console as the explicit `console-web` fallback while making `console` / `console-exe` open the native executable.
- Refined the native console visual design with an industrial gradient header, card-style sections, rounded action buttons, styled project tree, clearer run list, and terminal-like log preview areas.
- Upgraded the native console into a resizable desktop cockpit with automatic TIA project detection, browse/open actions, draggable left project tree, switchable AI/log/preview pages, bottom model/workflow task input, and Windows font-library selection.
- Added WinCC visual AI routing to the native console: task-aware model defaults, API/image parameter controls, reference-image upload and preview, and generated component-mapping/design prompts for text-to-image or image-to-image HMI workflows.
- Added an IDE-style native menu bar with File/Edit/View/Navigation/Code/Refactor/Run/Tools/Git/Window/Help menus, moved settings into a scrollable Tools drop-down panel, and reduced bottom-panel crowding to prevent overlapping controls.
- Trimmed the native console header into a compact one-line project toolbar and wrapped the main workspace in a right-side scrollable canvas with mouse-wheel support.
- Added a WinCC visual AI workflow reference for turning uploaded screenshots or text descriptions into WinCC-native screens, faceplates, tags, alarms, navigation, and SiVArc/Openess implementation plans.
- Validated the installed skill path after TIA/Openness reinstall on 2026-09-07: `read-cycle -ProjectPath "D:\plc\手动程序" -Attach -SkipExport` detected `V17` and `PLC_1`.
- Added a reusable knowledge-retrieval reference plus broader official instruction-family links for math, conversion, string, word-logic, and shift/rotate routes.
- Added new source-backed training examples for analog scaling/conditioning and status-word packing/decoding.
- Added root-level `CLAUDE.md` and `.cursorrules` files so the same repository instructions work in Claude Code and Cursor.

## 1.0.0 - 2026-08-10

- Packaged the reusable Siemens TIA Codex skill suite into a distributable repository.
- Included `siemens-tia-plc-dev`, `tia-portal-v17`, and `codex-tia-client`.
- Hardened the release copy so sibling skills resolve locally before falling back to `%USERPROFILE%\.codex\skills`.
- Excluded machine-local Siemens runtime binaries, caches, and transient artifacts from the distributable package.
- Preserved validated LAD authoring, import, compile, and readback workflows, including timer-backed and batch LAD cases.
- Sanitized machine-specific paths so the repository can be published as a reusable public release.
