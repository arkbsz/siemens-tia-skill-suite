# Reset Fanout

Source case:

- `D:\plc\手动程序\PLC_Code\changes\fc1-reset-fanout-freewrite\network15.json`

What it shows:

- one series reset condition chain
- multiple `RESET` actions on the same rung
- one `SET` action in the same fanout
- a real imported and compiled maintenance-style reset network on `FC1_报警程序块`

Use it when one operator reset should clear several alarm bits and also trigger one downstream reset flag.
