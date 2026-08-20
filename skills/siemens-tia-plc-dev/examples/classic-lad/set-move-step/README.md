# Set Move Step

What it shows:

- one step compare and permissive chain
- one output `SET` action and one `MOVE` action in the same rung
- the mixed-action fanout rule needed for TIA import stability

Typical use:

- drive one actuator command and advance the sequence step together
- ladder-based station steps that should stay easy for maintenance staff to read

Validation note:

- the underlying pattern was validated on July 22, 2026 against the real `D:\plc\手动程序` project clone flow
- accepted gate: `ImportExitCode=0`, `CompileExitCode=0`, `ExportExitCode=0`
