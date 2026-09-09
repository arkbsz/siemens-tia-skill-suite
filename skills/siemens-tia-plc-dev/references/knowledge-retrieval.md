# Knowledge Retrieval

Use this reference when Codex should actively look up Siemens PLC knowledge during authoring instead of relying only on remembered patterns.

## Source priority

Use sources in this order unless the user asks otherwise:

1. Siemens official instruction-family pages on `docs.tia.siemens.cloud`
2. Siemens official support manuals and Openness documents on `support.industry.siemens.com`
3. Siemens official GitHub Openness snippets
4. community case studies and open-source tooling that align with the requested workflow
5. the current project's exported LAD XML, summaries, SCL sources, tag names, and DB structures

## Retrieval loop

1. Summarize the target block or the closest existing project artifact first.
2. Classify the requested behavior by instruction family.
3. Read the official family page or manual section for that family.
4. Check whether the project already contains the same instruction or a close neighbor.
5. Choose the implementation route:
   - direct LAD JSON
   - generic `CALL`
   - SCL source import
   - donor-network patching
6. Implement the smallest reusable pattern first.
7. Validate by XML inspection, summary readback, and clone compile when Openness is ready.
8. Capture the lesson back into the skill only after the route is confirmed.

## What to prefer from each source type

- Official instruction pages:
  expected operands, data types, and family boundaries
- Official Openness docs:
  project traversal, export/import, compile, and write safety
- Official snippets:
  object-model access and API usage patterns
- Community examples:
  practical block structures, naming style, and engineering workflow shortcuts
- Current project exports:
  the exact `FlgNet` shape, symbol naming, and instance-DB conventions that the target project already accepts

## Search patterns

Use focused searches that include both the instruction name and the Siemens CPU family.

Examples:

- `docs.tia.siemens.cloud NORM_X S7-1200 S7-1500`
- `docs.tia.siemens.cloud SCALE_X S7-1200 S7-1500`
- `docs.tia.siemens.cloud SHL SHR S7-1200 S7-1500`
- `docs.tia.siemens.cloud string operations S7-1200 S7-1500`
- `support.industry.siemens.com TIA Portal Openness 109792902`
- `github siemens tia portal openness code snippets`

For community follow-up, prefer queries that keep Siemens and TIA Portal in scope:

- `site:github.com Siemens TIA Portal Openness example`
- `site:cnblogs.com TIA Portal Openness Siemens`
- `site:github.com Siemens PLCopen XML TIA Portal`

## Route discipline

- If the user needs maintenance-facing permissives, latches, timers, or counters, keep searching for a LAD-first route.
- If the requested instruction behaves like a typed block with named pins, search for an exported example and use generic `CALL`.
- If the requested logic is mostly scaling, conversion, string handling, buffering, masking, or recipe computation, search for an SCL-first route.
- If official docs explain the instruction semantics but the ladder XML shape is still unclear, export one donor network before adding or claiming a new direct LAD writer path.

## Timeout rule

If one website stalls or times out, do not wait indefinitely:

- switch from docs pages to support articles or official GitHub
- switch from web references to local exported project artifacts
- continue the authoring flow with the strongest confirmed source you already have

## Current user preference

For this skill suite, knowledge retrieval should prioritize:

- official Siemens tutorials and manuals
- community case studies and open-source tooling
- the structure and naming already present in the active TIA project

## 2026-09-09 Retrieval Notes

- TIA Portal Openness import/export is the authoritative engineering bridge for exported PLC/HMI artifacts. Siemens documents that export formats are internal and version-specific, so generated XML or document-style sources must be validated against the target TIA version before reuse across V16-V21.
- SiVArc is the preferred official route for rule-based WinCC generation, but generation should preflight the SiVArc license, valid HMI device name, valid PLC device name and supported device types before planning an automated HMI write.
- WinCC Unified GraphQL is useful for trusted runtime read/write/subscribe smoke tests after engineering generation, not as a replacement for engineering-time Openness/SiVArc screen creation.
- Community tools and MCP servers are useful patterns for bulk export/import, AI adapter routing, XML snapshots and semantic diffs. Treat them as source references or reviewed adapters first; do not execute downloaded binaries in a production project without source, license, provenance and clone behavior review.
- For "replace TIA editor" goals, prefer the proven loop: export blocks or SimaticML, normalize into code-like artifacts, generate small LAD/SCL/DB/HMI deltas, import on a clone, compile, re-export/readback, generate a review package, then wait for explicit production-apply intent.

Source anchors checked on 2026-09-09:

- `https://docs.tia.siemens.cloud/r/en-us/v21/tia-portal-openness-api-for-automation-of-engineering-workflows/export/import/overview/basic-principles-of-importing/exporting`
- `https://docs.tia.siemens.cloud/r/en-us/v21/sivarc-openness/sivarc-generation`
- `https://docs.tia.siemens.cloud/r/en-us/v20/wincc-unified-graphql-rt-unified`
- `https://github.com/siemens/tia-portal-openness-code-snippets`
- `https://github.com/tia-portal-applications/CWC-in-WinCC-Unified`
