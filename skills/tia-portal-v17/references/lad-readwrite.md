# LAD Read/Write

LAD ladder logic should be treated as TIA-owned structured XML, not as a casual text language.

## Supported path

Reliable read/write for LAD uses one of these TIA Openness paths:

- XML export/import through `PlcBlock.Export(...)` and `PlcBlockComposition.Import(...)`
- document export/import only if the local TIA version exposes `ExportAsDocuments(...)` and `ImportFromDocuments(...)`

The exported LAD/FBD XML contains:

- `SW.Blocks.CompileUnit` elements for networks in V17 exports
- `FlgNet` graph data for LAD/FBD logic
- `Part` elements for contacts, coils, boxes, calls, and other instructions
- `Wire` elements for power-flow and signal connections
- access/symbol nodes for operands

## Reading ladder logic

Use `scripts/inspect-lad-xml.ps1` on exported XML:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\tia-portal-v17\scripts\inspect-lad-xml.ps1" -Path "D:\path\to\block.xml"
```

The output is JSON with network counts, part counts, wire counts, instruction names, and symbols found.

Export from a live V17 project with:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\tia-portal-v17\scripts\invoke-tia-openness.ps1" export-blocks --project "D:\path\to\project" --language LAD --output "D:\path\to\project\PLC_Code\exports\lad"
```

The helper skips inconsistent blocks by default and reports them. Compile/fix the block or add `--include-inconsistent` only when deliberately testing export behavior.

Create code-like network summaries with:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\tia-portal-v17\scripts\summarize-lad-xml.ps1" -Path "D:\path\to\block.xml" -OutputPath "D:\path\to\block.lad.md"
```

The Markdown output uses simple pseudo-code such as:

```text
IF NO(自动中) AND NC(步进_左极限)
THEN SET(DB1_报警数据块.步进左极限报警)
```

Build a folder-level template catalog with:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\tia-portal-v17\scripts\build-lad-template-catalog.ps1" -Path "D:\path\to\project\PLC_Code\ladders" -OutputPath "D:\path\to\project\PLC_Code\reports\lad-template-catalog.md"
```

This produces a Markdown and JSON catalog of every network, which makes it much easier to search for reusable alarm, interlock, timer, and output patterns before editing XML.

Export a single network as a reusable template manifest with:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\tia-portal-v17\scripts\export-lad-network-template.ps1" -SourceXml "D:\path\to\block.xml" -NetworkIndex 1 -OutputPath "D:\path\to\project\PLC_Code\templates\lad\my-template.template.json" -TemplateName "my-template"
```

Build an index of saved templates with:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\tia-portal-v17\scripts\build-lad-template-index.ps1" -Path "D:\path\to\project\PLC_Code\templates\lad" -OutputPath "D:\path\to\project\PLC_Code\templates\lad\template-index.md"
```

Use this when you want a project-specific library of reusable alarm, timeout, output, and sequence networks.

## Writing ladder logic

Preferred write flow:

1. Export the existing LAD block from TIA.
2. Keep the original XML in `PLC_Code\exports`.
3. Copy it to `PLC_Code\ladders` for editing.
4. Modify one network at a time.
5. Run `validate-lad-xml.ps1`.
6. Preview import with `import-blocks` without `--apply`.
7. Import into a backup project with `import-blocks ... --apply`.
8. Compile with `compile-plc`.
8. Export again and compare.

## Editing rules

- Preserve XML namespaces, IDs, block metadata, and compile-unit structure unless the exact format is understood.
- Prefer changing operands, comments, network titles, and existing part parameters before creating new graph topologies.
- When adding new logic, copy a similar existing network and modify it rather than inventing raw graph XML from memory.
- For new LAD blocks, prefer creating a minimal block in TIA, exporting it, then editing the exported XML as a template.
- Do not run multiple TIA Openness project-open commands in parallel; V17 can conflict or return no useful output.

## Template edits

Use `apply-lad-template-replacements.ps1` for safe template-based edits to a full block XML:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\tia-portal-v17\scripts\apply-lad-template-replacements.ps1" `
  -SourceXml "D:\path\to\source.xml" `
  -OutputXml "D:\path\to\generated.xml" `
  -NetworkIndex 1 `
  -Replace "步进_左极限=步进_右极限;DB1_报警数据块.步进左极限报警=DB1_报警数据块.步进右极限报警" `
  -Title "模板生成_右限位报警" `
  -Comment "Generated from network 1 template"
```

This script modifies `Symbol/Component` nodes structurally and preserves the rest of the block XML. It is not a free-form text replacement. Always run `validate-lad-xml.ps1`, then summarize the generated XML before import preview.

## What "free editing" means here

Free editing is achieved through a code workspace and XML-aware tools:

- exported LAD XML is readable and diffable
- Codex can summarize networks and suggest edits
- Codex can patch XML files
- validation catches malformed XML before import
- Openness/MCP imports the edited artifact back into TIA

TIA compile remains authoritative.

## When to use SCL instead

Use SCL for algorithmic logic, loops, calculations, parsing, and reusable utilities. Use LAD for maintenance-facing interlocks, manual circuits, latches, permissives, command coils, and diagnostics that electricians or commissioning staff expect to see graphically.
