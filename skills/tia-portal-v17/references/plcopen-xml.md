# PLCopen XML

Use this path when a diffable, transformable, or tool-friendly representation is more useful than a live TIA session.

## Best use cases

- export and review logic offline
- compare generated vs existing logic
- feed PLC logic into analysis pipelines
- normalize structures before code generation

## What to expect

PLCopen XML is strong for:

- structure extraction
- transformation workflows
- machine-generated validation
- integration with external tooling

It is weaker for:

- TIA-specific project metadata
- vendor-specific UI-only features
- assumptions about exact round-trip fidelity without testing

## Related ideas from the ecosystem

- `PLC2Skill` shows how PLC logic can map into higher-level skill or capability models
- `plcopen-go` is a useful backend direction for parsing and transforms

## Practical advice

- prefer export-first, transform-second
- preserve original artifacts for comparison
- document any assumptions about vendor-specific extensions
- validate re-import behavior on a backup project before trusting the result
