# Workflow Router

This skill uses a practical routing model adapted from modern TIA automation stacks.

## Path selection

### Source-only

Choose this when:

- the user shared SCL, LAD descriptions, tag tables, or XML exports
- the request is design, review, refactor, or explanation
- touching the live project is unnecessary

### Openness

Choose this when:

- the user wants repeatable engineering automation
- the project tree, devices, blocks, tags, or exports must be enumerated
- you need a robust path beyond screenshots and GUI clicking

Use Siemens official snippet patterns as the behavioral reference for object traversal and lifecycle handling.

### MCP

Choose this when:

- an MCP server already bridges the assistant to TIA Portal
- the user wants interactive project questions and direct responses from the project model
- read/write operations are better mediated by dedicated tools than ad hoc scripts

### PLCopen XML

Choose this when:

- you need interchange, transformation, or offline review
- you want a diffable artifact
- you are building generation or validation pipelines

### GUI fallback

Choose this only when another path is blocked and the user still needs a TIA-only screen or setting inspected.

## Recommended sequence

1. Backup
2. Probe environment
3. Gather facts
4. Choose path
5. Do the smallest safe action
6. Validate

## Common task mapping

- "Read project structure" -> Openness or MCP
- "Generate FB/FC/DB logic" -> Source-only first
- "Bulk export/import" -> Openness
- "Compare versions" -> PLCopen XML or exported source
- "Check an HMI property hidden in UI" -> GUI fallback
