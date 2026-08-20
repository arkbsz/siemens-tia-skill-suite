# GUI Download Bridge

Use this when the project is ready and you want the REST bridge to prepare a visible TIA session for manual PLC download.

## Why this exists

Direct PLC download is high risk. The bridge should help with:

- opening the correct project in visible TIA
- compiling first
- exposing device information
- keeping one warm attached session for the final manual download step

The actual final confirmation still happens inside TIA Portal.

## REST flow

Prepare a visible download session:

```powershell
Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8765/api/v1/download/prepare" -ContentType "application/json" -Body '{"projectPath":"D:\\plc\\skill_demo_start_stop\\skill_demo_start_stop","plcName":"PLC_1"}'
```

This opens TIA with UI, compiles the PLC, returns device information, and reports network adapters.

Close the visible download session when finished:

```powershell
Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8765/api/v1/download/close" -ContentType "application/json" -Body '{"projectPath":"D:\\plc\\skill_demo_start_stop\\skill_demo_start_stop"}'
```

## Recommended operator steps

1. Review the compile result.
2. Check the reported network adapters and ensure the engineering PC is on the PLC network.
3. In TIA, select the CPU and use `Download to device`.
4. Use `Accessible devices` to confirm the exact target.
5. Confirm the target IP and CPU identity before starting the download.

## Guardrails

- Do not use this on a live machine without confirming downtime tolerance.
- Do not assume the first discovered device is the correct target.
- Keep this layer GUI-assisted unless you have a verified and reversible fully automated download route.
