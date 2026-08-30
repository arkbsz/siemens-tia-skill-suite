# MB COMM LOAD Call

What it shows:

- one action-only generic `CALL` for `MB_COMM_LOAD`
- `powerRail` driven `en`
- `GlobalConstant` input via `constantName`
- mixed mapped and open outputs

Typical use:

- Modbus RTU port setup
- first-scan communication initialization
- block calls that should run without a contact rung in front

Validation note:

- the underlying pattern was validated on July 22, 2026 against a real project clone flow
- accepted gate: `ImportExitCode=0`, `CompileExitCode=0`, `ExportExitCode=0`
