# MCP Workflow

This reference captures the useful idea from TIA-Portal MCP servers: expose TIA project operations as safe assistant tools rather than custom one-off scripts.

## When MCP is the best path

Use MCP when:

- the server is already installed and wired into the client
- the user wants conversational browse/read/write behavior
- the task maps well to explicit tool calls such as:
  - open project
  - inspect structure
  - export blocks
  - compile
  - close project

## Typical flow

1. connect to TIA Portal
2. open project
3. inspect project tree
4. inspect target PLC software
5. read or export the relevant artifacts
6. if writing, preview if supported
7. compile or otherwise validate
8. close and disconnect

## Why this path is useful

- less brittle than GUI automation
- more interactive than hand-written Openness scripts
- easier to question the live project model

## Constraints

- MCP availability is environment-specific
- some servers target newer TIA versions than V17
- tool coverage varies by server implementation

If MCP is unavailable or version-misaligned, fall back to Openness or source-only work.
