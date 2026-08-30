# MB Master Read Frequency

What it shows:

- one compare condition feeding `MB_MASTER.REQ`
- one generic `CALL` for `MB_MASTER`
- one parallel `MOVE` on `powerRail`
- array-style `components` access for `DATA_PTR` and `MOVE.in`

Typical use:

- Modbus polling steps
- communication blocks with buffer pointers
- mixed call-and-copy ladder networks that must match exported TIA structure

Validation note:

- the underlying pattern was validated on July 22, 2026 against a real project clone flow
- accepted gate: `ImportExitCode=0`, `CompileExitCode=0`, `ExportExitCode=0`
