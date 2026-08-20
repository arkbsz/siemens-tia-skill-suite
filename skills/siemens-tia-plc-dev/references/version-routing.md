# Version Routing

This skill is intentionally generic, but this release packages a validated sibling bridge for TIA Portal V17.

## Packaged implementation

- packaged sibling skill: `tia-portal-v17`
- packaged helper entrypoint: `scripts\invoke-tia-openness.ps1`
- packaged ladder helpers:
  - `summarize-lad-xml.ps1`
  - `apply-lad-template-replacements.ps1`
  - `build-lad-template-catalog.ps1`
  - `export-lad-network-template.ps1`
  - `build-lad-template-index.ps1`

## Practical rule

- If the target machine is TIA Portal V17 and the local probe passes, use the packaged V17 bridge directly.
- Prefer the generic wrapper entrypoint `scripts\invoke-siemens-plc-dev.ps1` so the command surface stays stable even if the bridge version changes later.
- If the machine differs, keep the generic workflow but re-probe assemblies and method availability before assuming the same API surface.
- If document-style export/import is unavailable, use block XML export/import.

## Anti-stall rule

If the route you picked stalls:

1. stop the attempt
2. prefer local reflection and verified scripts over browsing
3. switch from live project access to exported XML where possible
4. fall back to attach mode or GUI only when needed