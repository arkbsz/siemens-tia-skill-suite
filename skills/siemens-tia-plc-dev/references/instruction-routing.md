# Instruction Routing

Use this reference when the goal is "cover most PLC instructions" without pretending every Siemens instruction should be authored the same way.

## Design rule

Do not force all instructions through one LAD JSON subset.

Instead, choose the narrowest route that matches the instruction family:

- direct LAD JSON for operator-facing logic that maintenance staff expect to read as ladder
- generic `CALL` for block-like technology, communication, and library instructions
- SCL source import for algorithmic, arithmetic, conversion, string, array, and bulk data logic
- donor-network patching when the instruction is available in exported LAD XML but not yet modeled in the JSON writer

## Practical coverage map

- Bit logic:
  `NO`, `NC`, `P_EDGE`, `N_EDGE`, `COIL`, `SET`, `RESET`
  Preferred route: direct LAD JSON

- Compare, timer, counter:
  `EQ`, `NE`, `GE`, `GT`, `LE`, `LT`, `TON`, `TOF`, `TP`, `CTU`, `CTD`, `CTUD`
  Preferred route: direct LAD JSON, then clone compile gate

- Move and simple selection:
  `MOVE`, `SEL`, simple multiplexing around one operator-facing state path
  Preferred route: direct LAD JSON for `MOVE`, SCL source import for `SEL` or wider value-selection logic

- Analog scaling and numeric conditioning:
  `NORM_X`, `SCALE_X`, `LIMIT`, `ABS`, `MIN`, `MAX`, `ROUND`, `TRUNC`
  Preferred route: SCL source import

- Word logic and bit packing:
  `AND`, `OR`, `XOR`, `NOT`, `SHL`, `SHR`, `ROL`, `ROR`, mask build/decode, status-word packing
  Preferred route: SCL source import unless the exact ladder box shape is already available from a donor network

- Conversion and data formatting:
  typed conversion instructions, enum or numeric casts, string formatting, buffer preparation
  Preferred route: SCL source import

- String, array, and bulk data handling:
  string operations, array transforms, `MOVE_BLK_VARIANT`, fill/copy patterns, recipe buffering
  Preferred route: SCL source import

- Date, time, and system data:
  system-time reads, timestamp handling, runtime diagnostic data
  Preferred route: generic `CALL` or SCL source import depending on whether the instruction appears as a block-like call surface

- Motion, drive, communication, and technology objects:
  `MC_*`, `MB_*`, vendor library FBs, communication FBs, technology calls
  Preferred route: generic `CALL` using the exported interface or official documentation

- Arithmetic and data handling:
  add/subtract/multiply/divide, limit/scale/normalize, conversion, string handling, array transforms, serialization, variant-heavy logic
  Preferred route: SCL source import unless a maintenance requirement makes LAD mandatory

- Unsupported LAD box instructions:
  anything whose exact `FlgNet` shape is not yet modeled safely
  Preferred route: export one donor network from TIA, patch only `NetworkSource` / `FlgNet`, then verify on a clone

## Why this is the stable route

This split matches Siemens' own surfaces:

- Openness is strong at project traversal, import/export, compile, and engineering automation
- standard instruction manuals define the logical instruction families, not one universal XML shorthand
- many real-world Siemens instructions behave like named blocks with typed pins, which is exactly what the generic `CALL` path is good at
- heavier algorithms stay safer and more reviewable in SCL than in oversized ladder boxes

## Rules for extending coverage

When adding a new instruction family to the skill:

1. Check whether it is a true built-in ladder part or a block-like call surface.
2. If the XML shape is stable and simple, add direct LAD JSON support.
3. If it is block-like, prefer generic `CALL`.
4. If it is algorithmic or data-heavy, prefer SCL source import.
5. Record one minimal example.
6. Do not claim compile validation until a clone import/compile/export loop passes.

## Current reusable anchors

- `examples/classic-lad/*`:
  use for contacts, compares, timers, counters, and typed block-call rung patterns
- `examples/classic-scl/analog-scaling-fc`:
  use for `NORM_X`, `SCALE_X`, `LIMIT`, `ABS`, and setpoint-selection patterns
- `examples/classic-scl/status-word-builder-fc`:
  use for `SEL`, conversion, `SHL`, `SHR`, masking, and command/status word handling
- exported project XML plus `summarize-lad` output:
  use as the source of truth for any new direct LAD writer shape

## Official references used for this routing

- TIA Portal Openness overview: `109792902`
- TIA Portal Openness getting started demo: `108716692`
- Siemens official Openness code snippets:
  `https://github.com/siemens/tia-portal-openness-code-snippets`
- S7-1200/S7-1500 Standard Instructions manual:
  `https://support.industry.siemens.com/cs/document/1214574`
- S7-1200/S7-1500 Programming Guideline:
  `https://support.industry.siemens.com/cs/document/81318674`
