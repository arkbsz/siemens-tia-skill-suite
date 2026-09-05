---
name: tia-portal-v17
description: "Use for Siemens TIA Portal V16-V21 work on this Windows machine: backing up projects, checking local Openness prerequisites, generating or reviewing SCL/LAD/FBD logic, planning safe project edits, and choosing between source-only work, Openness automation, MCP integration, PLCopen XML interchange, or GUI fallback for S7-1200/1500 projects."
---

# TIA Portal V16-V21

Use this skill for Siemens PLC engineering tasks on this machine, especially when the user has a local TIA Portal project and wants safe, practical help rather than generic PLC advice.

Prefer the sibling skill `siemens-tia-plc-dev` as the top-level entry when the task should stay version-agnostic. This skill keeps the legacy name `tia-portal-v17`, but the packaged bridge now routes projects and Openness layouts across `V16` through `V21`.

This skill is a router plus local playbook. It combines:

- TIA Portal Openness workflow ideas
- MCP-based project interaction ideas
- Siemens official Openness snippet patterns
- PLCopen XML interchange guidance
- local-machine safety steps for backup and environment checks

## Target model: PLC as code

Treat PLC work like normal software work whenever possible:

1. Export blocks/types/tags from TIA into a text workspace.
2. Edit SCL or LAD/FBD XML/document files with ordinary coding tools.
3. Run local static checks before touching TIA.
4. Import through Openness or MCP.
5. Compile in TIA and keep the exported source as the reviewable truth.

Create the workspace with:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\tia-portal-v17\scripts\init-plc-code-workspace.ps1" -ProjectPath "D:\path\to\project"
```

For details, read `references/plc-as-code.md`. For ladder logic specifically, read `references/lad-readwrite.md`.

Use the verified local Openness helper for project reads, LAD XML export/import previews, and PLC compile:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\tia-portal-v17\scripts\invoke-tia-openness.ps1" list-plcs --project "D:\path\to\project"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\tia-portal-v17\scripts\invoke-tia-openness.ps1" list-blocks --project "D:\path\to\project"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\tia-portal-v17\scripts\invoke-tia-openness.ps1" export-blocks --project "D:\path\to\project" --language LAD --output "D:\path\to\project\PLC_Code\exports\lad"
```

For code-like LAD review and template edits, use:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\tia-portal-v17\scripts\summarize-lad-xml.ps1" -Path "D:\path\to\block.xml" -OutputPath "D:\path\to\block.lad.md"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\tia-portal-v17\scripts\apply-lad-template-replacements.ps1" -SourceXml "D:\path\to\block.xml" -OutputXml "D:\path\to\generated.xml" -NetworkIndex 1 -Replace "OldTag=NewTag;OldDB.Member=NewDB.Member" -Title "Generated network title"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\tia-portal-v17\scripts\build-lad-template-catalog.ps1" -Path "D:\path\to\project\PLC_Code\ladders" -OutputPath "D:\path\to\project\PLC_Code\reports\lad-template-catalog.md"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\tia-portal-v17\scripts\export-lad-network-template.ps1" -SourceXml "D:\path\to\block.xml" -NetworkIndex 1 -OutputPath "D:\path\to\project\PLC_Code\templates\lad\my-template.template.json" -TemplateName "my-template"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\tia-portal-v17\scripts\build-lad-template-index.ps1" -Path "D:\path\to\project\PLC_Code\templates\lad" -OutputPath "D:\path\to\project\PLC_Code\templates\lad\template-index.md"
```

## First move

Before any write-like action, back up the project.

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\tia-portal-v17\scripts\backup-tia-project.ps1" -ProjectPath "D:\path\to\project"
```

If the user already confirmed a backup in this session, you do not need to repeat it.

## Local machine facts

This skill is tuned for a machine where one or more of these versions may be installed:

- `V16-V20`: `C:\Program Files\Siemens\Automation\Portal VXX\PublicAPI\VXX`
- `V21`: `C:\Program Files\Siemens\Automation\Portal V21\PublicAPI\V21\net48`
- typical project formats such as `.ap16` through `.ap21`

To verify the local environment, run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\tia-portal-v17\scripts\probe-tia-portal.ps1"
```

Treat `ReadyForOpennessSession` as the live-work gate. If `ConfiguredInSiemensTiaOpennessGroup` is `true` but `ActiveInCurrentLogonToken` is `false`, the user likely needs a full Windows sign-out and sign-in before Openness can connect. A new terminal window is usually not enough.

Downloaded local references are tracked in `references/downloaded-tools.md`.

## Routing

Choose the narrowest path that fits the task.

### 1. Source-only path

Use when the user has exported SCL, XML, tag tables, alarm tables, or just wants logic designed or reviewed without touching the live project.

Use:

- `references/lad-readwrite.md` for LAD/FBD XML
- `references/scl.md`
- `references/motor-control.md`
- `references/analog-io.md`
- `references/process-control.md`

Best for:

- FB/FC/DB design
- LAD/FBD network review and edits from exported XML
- sequence logic
- alarm strategy
- code review
- naming and structure cleanup

### 2. Openness path

Use when the user wants structured project automation such as reading blocks, traversing devices, exporting/importing artifacts, or building repeatable engineering tooling.

Read:

- `references/openness-workflow.md`
- `references/openness-readwrite-tool.md`
- `references/machine-notes.md`

Prefer this path for:

- project tree inspection
- block export/import planning
- device and software-container traversal
- scripted engineering tasks

Use Siemens official Openness snippets as the behavioral baseline. Prefer read-only inspection first, then narrow the exact write operation. Use `scripts/invoke-tia-openness.ps1` for the verified helper commands.

If the helper reports an Openness preflight failure, stop retrying the same live command and switch to one of these next steps:

- recover the Windows group/logon-session prerequisites
- keep working source-only from exported XML or SCL
- use GUI fallback only when a structured route is unavailable

### 3. MCP path

Use when a TIA-aware MCP server is available and interactive project read/write is the cleanest path.

Read:

- `references/mcp-workflow.md`
- `references/mcp-local-server.md`

Best for:

- conversational project browsing
- direct block/tag questions
- guided edits with tool mediation

Assume MCP is optional, not guaranteed. If unavailable, fall back to Openness or source-only work.

### 4. PLCopen XML path

Use when the user needs interchange, comparison, templating, offline review, or transformation outside TIA Portal.

Read:

- `references/plcopen-xml.md`

Best for:

- offline diff/review
- machine-generated XML transforms
- architecture extraction
- codegen pipelines

### 5. GUI fallback path

Use only when the engineering goal cannot be completed through exported sources, Openness, or MCP.

Typical cases:

- confirming a UI-only setting
- navigating a project page that is not exposed by current automation
- collecting visual evidence from the open TIA Portal window

Keep GUI work conservative:

- back up first
- inspect before clicking
- prefer read-only actions
- narrate assumptions

## Safe workflow

For nontrivial project work, follow this order:

1. Back up the project.
2. Identify the artifact type: live `.ap16` through `.ap21`, exported source, XML, screenshots, or mixed.
3. Identify the goal: inspect, review, generate, import, refactor, debug, or document.
4. Choose one primary path from the routing section.
5. Gather exact project facts before proposing edits:
   - CPU family
   - language used
   - block names
   - I/O conventions
   - safety or HMI involvement
6. Make the smallest coherent change.
7. Validate using the strongest available method:
   - compile in TIA
   - static consistency checks
   - exported XML review
   - block-level reasoning against requirements
8. Summarize risks that remain.

## Guardrails

- Never modify a TIA project without either a fresh backup or explicit user approval to proceed without one.
- Prefer exported text or XML artifacts over blind binary project manipulation.
- Do not assume Openness write access is working just because the DLLs exist.
- Do not assume Windows group membership is active in the current session just because the user was added earlier; `ActiveInCurrentLogonToken` must also be `true`.
- Treat Safety, motion, drives, and online/download operations as high risk; explain before changing.
- When the project is only partially readable, state that clearly and work from confirmed facts only.
- If TIA files are locked, do not force destructive recovery. Use backup snapshot mode and tell the user what was locked.

## References

- Route selection and execution: `references/workflow-router.md`
- PLC-as-code workspace: `references/plc-as-code.md`
- LAD read/write: `references/lad-readwrite.md`
- Downloaded local tools: `references/downloaded-tools.md`
- Local installation and constraints: `references/machine-notes.md`
- Openness-oriented project work: `references/openness-workflow.md`
- Openness read/write helper design: `references/openness-readwrite-tool.md`
- MCP-oriented project work: `references/mcp-workflow.md`
- Local MCP server notes: `references/mcp-local-server.md`
- PLCopen XML strategy: `references/plcopen-xml.md`
- SCL and process patterns:
  - `references/scl.md`
  - `references/analog-io.md`
  - `references/motor-control.md`
  - `references/process-control.md`
