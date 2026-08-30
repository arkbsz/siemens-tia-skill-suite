# Changelog

## 1.0.0 - 2026-08-10

- Packaged the reusable Siemens TIA Codex skill suite into a distributable repository.
- Included `siemens-tia-plc-dev`, `tia-portal-v17`, and `codex-tia-client`.
- Hardened the release copy so sibling skills resolve locally before falling back to `%USERPROFILE%\.codex\skills`.
- Excluded machine-local Siemens runtime binaries, caches, and transient artifacts from the distributable package.
- Preserved validated LAD authoring, import, compile, and readback workflows, including timer-backed and batch LAD cases.
- Sanitized machine-specific paths so the repository can be published as a reusable public release.
