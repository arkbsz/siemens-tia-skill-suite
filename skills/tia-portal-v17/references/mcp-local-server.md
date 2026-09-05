# Local MCP Server Notes

This release does not bundle any third-party MCP server executable. Treat MCP as an optional extension layer on top of the packaged Openness workflow.

## Use when

- the user wants conversational browse/read/write against an open TIA project
- a compatible local MCP server is already installed on the target machine
- the server starts cleanly against the target machine's TIA Portal version

## Setup checks

- A matching TIA Portal V16, V17, V18, V19, V20, or V21 installation is available and can start
- the current user belongs to `Siemens TIA Openness` if write operations are required
- the MCP server can resolve Siemens Openness assemblies from the local TIA install
- any configured `TiaPortalLocation` points at the target machine's local TIA install directory

## Codex use

If MCP tools are not registered in the current Codex session, do not assume they exist. Use the packaged Openness scripts first, then wire in MCP only when it improves read/write ergonomics on that workstation.

## Suggested configuration shape

For a VS Code-style MCP setup, keep the structure generic and fill in local machine paths during installation:

```json
{
  "servers": {
    "tia-portal-mcp": {
      "command": "C:\\path\\to\\YourTiaMcpServer.exe",
      "args": [],
      "env": {
        "TiaPortalLocation": "C:\\Program Files\\Siemens\\Automation\\Portal V16"
      }
    }
  }
}
```

Validate with a read-only task before attempting writes.
