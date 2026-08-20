# Siemens TIA Skill Suite

Version: 1.0.0
Release date: 2026-08-10

This package bundles the reusable Siemens/TIA Codex skills that were hardened during the recent LAD authoring, import, compile, and readback loops.

Included skills:

- siemens-tia-plc-dev: generic Siemens PLC workflow wrapper
- 	ia-portal-v17: local V17 bridge and Openness helper surface
- codex-tia-client: Codex-first entrypoint for backup, export, write, import, and compile loops

What is intentionally excluded:

- Siemens.Engineering.dll
- Siemens.Engineering.Hmi.dll
- prebuilt TiaPlcTool.exe
- session caches and Python bytecode

Why those binaries are excluded:

- the target machine should bind to its own installed TIA Portal V17 PublicAPI
- the packaged invoke-tia-openness.ps1 recompiles TiaPlcTool.exe locally on first use
- this keeps the release safer for redistribution and less coupled to one workstation snapshot

Install:

1. Extract this archive.
2. Run install-skills.ps1.
3. Restart Codex if it was already open.

Default install target:

- %USERPROFILE%\.codex\skills

Prerequisites on the target machine:

- TIA Portal V17
- Openness PublicAPI available under the TIA install
- .NET Framework 4.8
- Windows user configured for Siemens TIA Openness when write workflows are needed

Validation basis:

- the packaged skills were used to complete offline ackup -> source import -> block import -> compile -> LAD export/readback loops
- the recent industrialization/simulation overlay validated DB_7SimulationPanel, FC7_SimulationIO, and TON.PT bound to a DB TIME variable