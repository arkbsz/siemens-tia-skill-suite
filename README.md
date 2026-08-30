# Siemens TIA Skill Suite

Version: `1.0.0`  
Release date: `2026-08-10`

This repository packages a reusable Siemens TIA Portal skill suite for Codex. It is designed to support practical PLC-as-code workflows such as project backup, block export, LAD XML editing, source import, compile verification, and local Openness or REST-bridge based automation.

## Included Skills

- `siemens-tia-plc-dev`: generic Siemens PLC workflow wrapper
- `tia-portal-v17`: local TIA Portal V17 bridge and Openness helper surface
- `codex-tia-client`: Codex-first entrypoint for backup, export, write, import, and compile loops

## What Is Intentionally Excluded

- `Siemens.Engineering.dll`
- `Siemens.Engineering.Hmi.dll`
- prebuilt `TiaPlcTool.exe`
- session caches and Python bytecode

These binaries are excluded so the package can bind to the target machine's own TIA Portal V17 PublicAPI installation and rebuild local helper binaries when needed.

## Install

1. Download or extract this repository.
2. Run `install-skills.ps1`.
3. Restart Codex if it is already open.

Default install target:

- `%USERPROFILE%\.codex\skills`

## Target Machine Prerequisites

- TIA Portal V17
- Openness PublicAPI available under the local TIA installation
- .NET Framework 4.8 or compatible local build environment
- A Windows user configured for `Siemens TIA Openness` when write workflows are required

## Repository Layout

- `skills/`: packaged Codex skills
- `install-skills.ps1`: local installer for the skill suite
- `release-manifest.json`: packaged metadata and validation record
- `LICENSE`: MIT license for the repository

## Validation Basis

- The packaged skills were used to complete offline `backup -> source import -> block import -> compile -> LAD export/readback` loops.
- The validated ladder workflow includes timer-backed LAD changes, batch network rewrites, and support-source import for helper DB artifacts.
- The recent industrialization and simulation overlay validated `DB_7SimulationPanel`, `FC7_SimulationIO`, and `TON.PT` bound to a DB `TIME` variable.

## Notes

- Prefer working on a backup or clone before importing changes into a main project.
- Use exported XML and SCL artifacts as the reviewable source of truth whenever possible.
- Treat this repository as a distributable skill suite, not as a bundle of Siemens runtime binaries.
