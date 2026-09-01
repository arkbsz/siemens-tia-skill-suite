# PLC As Code

Goal: make Siemens PLC work feel like normal code work without pretending TIA Portal is a plain-text project.

## Working model

Use a text workspace beside or inside the project:

```text
PLC_Code/
  blocks/
  ladders/
  types/
  tags/
  alarms/
  imports/
  exports/
  reports/
  manifest.json
```

The `.ap17` through `.ap21` project remains the source of truth inside TIA. The text workspace is the reviewable engineering surface used by Codex, git, diff tools, and import/export scripts.

## Recommended loop

1. Back up the TIA project.
2. Export existing PLC blocks/types/tags into `PLC_Code/exports`.
3. Edit or generate files in `PLC_Code/blocks`, `PLC_Code/types`, and `PLC_Code/tags`.
4. Run text-level checks.
5. Import into a backup project with Openness or MCP.
6. Compile in TIA.
7. Export again and compare.

## File formats

- Prefer TIA Openness XML for exact round-tripping.
- Use `.scl` for human-authored source blocks and new logic.
- Use LAD/FBD XML or SIMATIC SD document exports for ladder logic.
- Use `.json` manifests for import order, PLC target names, and warnings.
- Keep generated files separate from exported files.

## Guardrails

- Do not directly edit internal `System\PEData.*`, `XRef.db`, or `Vci.db`.
- Do not overwrite imported blocks without an import manifest and backup.
- Treat Safety, motion, drives, technology objects, and online/download operations as high-risk.
- For S7-300/400, verify DB optimization assumptions before import.

## Local scripts

- `scripts/init-plc-code-workspace.ps1` creates the workspace.
- `scripts/check-scl-package.ps1` performs lightweight textual checks on generated SCL.
- `scripts/inspect-lad-xml.ps1` summarizes exported LAD/FBD XML networks.
- `scripts/validate-lad-xml.ps1` checks exported LAD/FBD XML against the local TIA XSDs when possible.
- `scripts/backup-tia-project.ps1` creates the rollback point.
