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

Before any write-like action, back up the project or work on a clone.
When PLC and HMI data must align, stabilize the PLC tag/DB contract first, then mirror it in the HMI.
If the exact WinCC flavor or installed API version is unclear, inspect the local TIA installation before assuming a DLL or method exists.

Read `references/official-sources.md` for the capability boundaries and `references/workflow.md` for the recommended edit loop.
