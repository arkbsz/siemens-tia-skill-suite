# TIA REST Client

This is a minimal Node-based client template for the local Siemens TIA REST bridge.

## Usage

From this folder:

```powershell
node ./src/demo.mjs health
node ./src/demo.mjs open-session "D:\plc\skill_demo_start_stop\skill_demo_start_stop"
node ./src/demo.mjs plcs "D:\plc\skill_demo_start_stop\skill_demo_start_stop"
node ./src/demo.mjs blocks "D:\plc\skill_demo_start_stop\skill_demo_start_stop" "PLC_1"
node ./src/demo.mjs prepare-download "D:\plc\skill_demo_start_stop\skill_demo_start_stop" "PLC_1"
```

## Notes

- The default REST endpoint is `http://127.0.0.1:8765`.
- Override it with `TIA_REST_BASE_URL`.
- The client uses built-in `fetch` from modern Node.
