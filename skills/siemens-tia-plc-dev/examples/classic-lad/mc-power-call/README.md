# MC Power Call

What it shows:

- one generic `CALL` action for `MC_Power`
- one condition path into `Enable`
- one `powerRail` root into `en`
- named inputs plus open outputs

Typical use:

- axis enable logic
- PLCopen motion control block calls
- readable motion-facing LAD that still compiles from JSON

Validation note:

- the underlying pattern was validated on July 22, 2026 against the real `D:\plc\手动程序` project clone flow
- accepted gate: `ImportExitCode=0`, `CompileExitCode=0`, `ExportExitCode=0`
