# CTU Reset Step

What it shows:

- one `P_EDGE` count path into a `CTU`
- one separate reset path built from OR-ed reset conditions
- one reusable counter instance DB pattern for step or pulse counting logic

Typical use:

- single-step jog counters
- sequence counters with reset and overflow handling
- maintenance-facing count logic that should stay in LAD

Validation note:

- the underlying pattern was validated on July 22, 2026 against a real project clone flow
- accepted gate: `ImportExitCode=0`, `CompileExitCode=0`, `ExportExitCode=0`
