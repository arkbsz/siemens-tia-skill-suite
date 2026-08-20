# VS Code Client Template

Use this when you want a project-local VS Code starter that talks to the local TIA REST bridge.

## Scaffold into a project

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\scaffold-vscode-rest-client.ps1" -ProjectPath "D:\path\to\project"
```

## What it adds

- `.vscode\tasks.json`
- `.vscode\extensions.json`
- `tia-rest.http`
- `tools\tia-rest-client\package.json`
- `tools\tia-rest-client\src\tiaRestClient.mjs`
- `tools\tia-rest-client\src\demo.mjs`
- `tools\tia-rest-client\README.md`

## Typical flow

1. Start the local REST bridge.
2. Open the project in VS Code.
3. Run the `TIA: List PLCs` or `TIA: List Blocks` task.
4. Use `tia-rest.http` for quick manual requests.
5. Extend `tools\tia-rest-client\src\tiaRestClient.mjs` for editor automation or custom panels.

## Notes

- The template assumes the bridge is at `http://127.0.0.1:8765`.
- Node 18 or newer is recommended because it includes `fetch`.
- The client stays editor-side only; all TIA/Openness coupling remains in the local bridge.
