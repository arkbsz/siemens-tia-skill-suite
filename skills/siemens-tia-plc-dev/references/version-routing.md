# Version Routing

This skill is intentionally generic. This release keeps the legacy sibling name `tia-portal-v17`, but the packaged bridge now routes TIA Portal `V16` through `V21`.

## Packaged implementation

- packaged sibling skill: `tia-portal-v17`
- packaged helper entrypoint: `scripts\invoke-tia-openness.ps1`
- packaged version resolver: `scripts\resolve-tia-portal.ps1`
- packaged ladder helpers:
  - `summarize-lad-xml.ps1`
  - `apply-lad-template-replacements.ps1`
  - `build-lad-template-catalog.ps1`
  - `export-lad-network-template.ps1`
  - `build-lad-template-index.ps1`

## Practical rule

- Use `doctor` or `probe` first so the bridge can detect the project suffix, installed TIA version, and Openness assembly layout.
- Prefer the generic wrapper entrypoint `scripts\invoke-siemens-plc-dev.ps1` so the command surface stays stable even if the bridge version changes later.
- `V16` through `V20` use the classic monolithic Openness layout.
- `V21` uses modular assemblies under `PublicAPI\V21\net48`, so helper builds must switch references.
- If document-style export/import is unavailable, use block XML export/import.

For the version-by-version differences that affect the skill behavior, also read `references/version-compatibility-v16-v21.md`.

## Anti-stall rule

If the route you picked stalls:

1. stop the attempt
2. prefer local reflection and verified scripts over browsing
3. switch from live project access to exported XML where possible
4. fall back to attach mode or GUI only when needed
