# Changelog

## Unreleased

- Added `siemens-wincc-hmi-dev` for WinCC HMI automation workflows.
- Updated the release package metadata and installer to include the WinCC skill.
- Expanded `siemens-tia-plc-dev` with instruction-routing guidance so most Siemens instruction families can be routed through LAD JSON, generic `CALL`, SCL source import, or donor-network patching.
- Added direct LAD JSON generation support for `TOF`, `TP`, `CTD`, and `CTUD`, plus new reusable example specs.
- Updated `summarize-lad-xml.ps1` to read back `TOF`, `TP`, `CTD`, and `CTUD` networks into human-readable summaries.
- Hardened the Openness workflow with structured readiness fields in `probe-tia-v17.ps1`, a `doctor` alias in the generic wrapper, and fail-fast preflight checks before live Openness commands or clone-based LAD verification.
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
