# Ecosystem And Next Routes

This skill is designed to stay useful even when the local automation route changes.

## Current generic architecture

- generic top-level entry: `scripts\invoke-siemens-plc-dev.ps1`
- versioned local bridge: sibling skills such as `tia-portal-v17`
- source workspace: `PLC_Code`
- read and write focus: exported XML, summaries, templates, import preview, compile, re-export

## Why this shape

The current Siemens and community ecosystem points in the same direction:

- official TIA Portal Openness remains the core automation API surface
- Siemens publishes Openness overview and getting-started material
- Siemens also publishes Openness code snippets as a practical baseline
- Siemens has a Python-oriented TIA Scripting route for easier automation tasks
- community MCP bridges connect TIA Portal to chat-driven tooling

## Practical extension routes

### 1. Keep the current bridge model

Best when:

- the machine version is known
- Openness DLLs are installed locally
- you need reliable export, import, compile, and block traversal

### 2. Add a Python bridge

Best when:

- the task is repetitive engineering automation
- the team wants easier scripting than C# for day-to-day tasks
- the machine has a supported TIA scripting toolchain

### 2.5. Add a local REST bridge

Best when:

- editors or agents should use HTTP instead of loading TIA APIs directly
- one local machine owns the Openness dependency and version coupling
- multiple tools should reuse the same guarded command surface

### 3. Add an MCP bridge

Best when:

- the user wants conversational project browsing and edits
- the editor or agent runtime supports MCP cleanly
- the installed TIA version matches the MCP server capability

### 4. Keep exported XML as the stable interchange layer

Best when:

- versions differ across machines
- live project access is blocked or slow
- reviewability and diffability matter more than direct online edits

### 5. Add offline graphical preview adapters

Best when:

- the user wants LAD/FBD/GRAPH readability without opening TIA editors for every review
- exported SimaticML, `.scl`, `.db`, `.udt`, or document-style sources are available
- the adapter is used read-only for preview and diff before any import

Community TIA Viewer / ImportExport style tools are useful references for this route. Review source and license before reuse, and keep the workbench writer path separate from a viewer path.

## Design rule for future versions

Do not let the top-level workflow depend on one TIA version.

Instead:

1. keep the generic wrapper stable
2. swap or add versioned bridge skills underneath it
3. preserve the same `PLC_Code` workspace contract
4. keep LAD review centered on exported XML, summaries, templates, and validation
