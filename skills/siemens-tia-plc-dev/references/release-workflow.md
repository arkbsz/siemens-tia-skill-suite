# Release Workflow

Use this when a block change is ready to move from a working package into a reusable release or into the main project.

## Two stages

### 1. Prepare a release package

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" prepare-release -ProjectPath "D:\path\to\project" -InputXml "D:\path\to\change.generated.xml" -ReleaseName "fc1-cleanup"
```

### 2. Apply a release package

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" apply-release -ProjectPath "D:\path\to\project" -InputXml "D:\path\to\release.xml" -PlcName "PLC_1"
```

## What the apply step does

1. backup the project
2. dry-run the import
3. apply the import
4. compile and save
5. re-export the changed block
6. generate a readable summary when the block is LAD

## Guardrail

Do not run `apply-release` in parallel with other TIA open-project commands.
