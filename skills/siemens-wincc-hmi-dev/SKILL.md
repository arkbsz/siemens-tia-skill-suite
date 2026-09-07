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

Read `references/official-sources.md` for the capability boundaries, `references/workflow.md` for the recommended edit loop, `references/screen-design.md` for layout, navigation, and visual quality rules, and `references/visual-ai-workflow.md` when the task uses text descriptions or uploaded reference images to drive WinCC screen design.
