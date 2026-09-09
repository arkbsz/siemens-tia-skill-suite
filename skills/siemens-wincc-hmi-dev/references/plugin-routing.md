# WinCC plugin routing

Use `scripts/resolve-wincc-plugins.ps1` at the start of a WinCC design task:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\resolve-wincc-plugins.ps1 -ProjectPath "D:\path\to\project" -WorkflowConfigPath "D:\path\to\project\PLC_Code\config\ai-workflow.json" -TaskText "Create a WinCC overview screen" -RefreshCatalog
```

The resolver writes `PLC_Code\wincc\plugin-routing.json`. The native console exposes the same operation through the `WinCC插件` button and automatically embeds the cached route in generated WinCC task prompts.

## Selection order

1. Use the bundled `$imagegen` skill for text-to-image or reference-guided visual concepts.
2. Use the matching local Siemens Openness API for engineering-time screen, tag, alarm, faceplate, and script work.
3. Use SiVArc only when its API and license are detected and the design repeats a stable equipment/station pattern.
4. On V20/V21, an explicitly configured and reviewed TIA Portal Openness MCP can replace the local engineering adapter for supported Unified objects.
5. Use V20 Unified MCP style adapters only after source/license review and only on a clone until V21/V16-V19 behavior is proven.
6. Use TIA Openness Manager style tools as bulk import/export and review references; keep writer behavior disabled until validated on a clone.
7. Use TIA Add-In ShowScripts on compatible Unified projects to export screen JavaScript for review; it is an audit/export adapter, not a general screen writer.
8. Use the WinCC Unified GraphQL MCP only for runtime validation after its endpoint and local server path are configured.
9. Use Custom Web Controls only when standard controls and reusable faceplates cannot meet the requirement. Verify license and source before copying community controls.
10. Use TIA Viewer / ImportExport style tools only as read-only offline preview adapters for exported SimaticML, LAD/FBD, GRAPH, SCL, DB or UDT artifacts until the source, license and write behavior have been reviewed.

## Configuration

The native console stores these fields in `PLC_Code\config\ai-workflow.json` under `wincc`:

- `flavor`: automatic, Advanced/Comfort, Unified Engineering, Unified Runtime, or SiVArc
- `pluginPolicy`: automatic, official/local only, reviewed community plugins, or disabled
- `graphqlUrl`: Unified runtime GraphQL endpoint; do not store credentials here
- `runtimeMcpPath`: reviewed local `winccua-mcp-server` entry point
- `tiaMcpPath`: reviewed local TIA MCP executable
- `tiaV20UnifiedMcpPath`: reviewed local V20 Unified MCP path when this route is selected for V20/V21 experiments
- `tiaOpennessManagerPath`: reviewed local TIA Openness Manager path for read/review or clone-only workflows
- `showScriptsPath`: reviewed ShowScripts Add-In or console executable
- `tiaViewerPath`: reviewed or source-available offline viewer/import-export adapter for graphical/source previews

Use environment variables for secrets. Runtime writes, alarm acknowledgement, and reset operations remain disabled unless the user explicitly asks for them.

## Researched adapters

The maintained catalog is `references/wincc-plugin-catalog.json`. Its current external sources include:

- `bulaofen0036-coder/TIA_Portal_Openness_MCP`: strong V20/V21 declarative PLC and Unified HMI coverage; MIT; community executable requires review.
- `tia-portal-applications/TIA-Add-In-ShowScripts`: exports Unified screen JavaScript and screen summaries; useful from V17 with documented API limitations.
- `Fanqi-dev/tia-v20-unified-mcp`: community MCP workflow reference for V20 Unified-style project/XML/compile automation; verify version support and license before use.
- `tiaopenessmanager.ch/en`: TIAOpenessManager / AnyAutomation Studio workflow reference for bulk import/export and review; do not run against customer projects before reviewing source/provenance, license and backup behavior.
- `vogler75/winccua-mcp-server`: Unified GraphQL runtime tags and alarms; GPL-3.0; trusted-network use only.
- `tia-portal-applications/CWC-in-WinCC-Unified`: Custom Web Control development and packaging reference.
- `Rynstick/LBS`: broad community Unified component library; verify its license and dependencies before reuse.
- `Parozzz/TiaUtilities`: useful source pattern for TIA Add-In, XML import/export and code-generation workflows; treat writer behavior as review-required.
