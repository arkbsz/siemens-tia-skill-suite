# REST Bridge

Use this when you want editor integrations that talk to TIA Portal through a local HTTP service instead of calling TIA directly.

## Architecture

- editor or client sends local REST requests
- `scripts\tia_rest_bridge.py` validates the request
- the server calls `scripts\invoke-siemens-plc-dev.ps1`
- the generic wrapper routes to the local `tia-portal-vXX` bridge
- the versioned bridge performs Openness work inside TIA Portal

This keeps editor-side code independent from direct TIA Portal assembly loading.

## Start the server

Foreground:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\start-tia-rest-bridge.ps1"
```

Background:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\start-tia-rest-bridge.ps1" -Background
```

Default URL:

`http://127.0.0.1:8765`

## Endpoints

- `GET /health`
- `GET /route-info`
- `GET /openapi.json`
- `GET /api/v1/sessions`
- `POST /api/v1/sessions/open`
- `POST /api/v1/sessions/close`
- `POST /api/v1/download/prepare`
- `POST /api/v1/download/close`
- `POST /api/v1/tia/create-project`
- `POST /api/v1/tia/list-devices`
- `POST /api/v1/tia/list-plcs`
- `POST /api/v1/tia/list-blocks`
- `POST /api/v1/tia/export-blocks`
- `POST /api/v1/tia/import-blocks`
- `POST /api/v1/tia/compile-plc`
- `POST /api/v1/lad/summarize`
- `POST /api/v1/lad/validate`
- `POST /api/v1/lad/patch-network`
- `POST /api/v1/releases/prepare`
- `POST /api/v1/releases/apply`
- `POST /api/v1/command`

## Example requests

Open a warm project session:

```powershell
Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8765/api/v1/sessions/open" -ContentType "application/json" -Body '{"projectPath":"D:\\plc\\skill_demo_start_stop\\skill_demo_start_stop","ui":false}'
```

List PLCs:

```powershell
Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8765/api/v1/tia/list-plcs" -ContentType "application/json" -Body '{"projectPath":"D:\\plc\\skill_demo_start_stop\\skill_demo_start_stop"}'
```

List blocks:

```powershell
Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8765/api/v1/tia/list-blocks" -ContentType "application/json" -Body '{"projectPath":"D:\\plc\\skill_demo_start_stop\\skill_demo_start_stop","plc":"PLC_1"}'
```

Compile:

```powershell
Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8765/api/v1/tia/compile-plc" -ContentType "application/json" -Body '{"projectPath":"D:\\plc\\skill_demo_start_stop\\skill_demo_start_stop","plc":"PLC_1","save":true}'
```

Use an already-open session for lower-latency project work:

```powershell
Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8765/api/v1/tia/list-blocks" -ContentType "application/json" -Body '{"projectPath":"D:\\plc\\skill_demo_start_stop\\skill_demo_start_stop","plc":"PLC_1","useSession":true}'
```

Patch one LAD network by replacing only `NetworkSource` / `FlgNet`:

```powershell
Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8765/api/v1/lad/patch-network" -ContentType "application/json" -Body '{"targetXml":"D:\\path\\to\\target.xml","donorXml":"D:\\path\\to\\donor.xml","outputXml":"D:\\path\\to\\patched.xml","targetNetworkIndex":1,"donorNetworkIndex":1,"copyTitle":true,"copyComment":true}'
```

Close the warm session:

```powershell
Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8765/api/v1/sessions/close" -ContentType "application/json" -Body '{"projectPath":"D:\\plc\\skill_demo_start_stop\\skill_demo_start_stop"}'
```

For future GUI download work, open the session with `"ui": true` so TIA stays visible while the REST bridge routes subsequent commands through `--attach`.

Prepare a visible GUI download session:

```powershell
Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8765/api/v1/download/prepare" -ContentType "application/json" -Body '{"projectPath":"D:\\plc\\skill_demo_start_stop\\skill_demo_start_stop","plcName":"PLC_1"}'
```

## Design notes

- bind to `127.0.0.1` by default
- keep the server local unless you add your own auth and transport hardening
- serialize TIA project operations through one local bridge process
- prefer warm sessions plus `--attach` for interactive editor workflows
- use release and clone workflows before applying changes to a production project
- on Windows PowerShell with non-ASCII project paths, first call `prepare-write-session` through the local wrapper and then reuse the returned ASCII `BridgeProjectPath` in REST requests when necessary
