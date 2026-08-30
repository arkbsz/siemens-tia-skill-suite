# Dual Move ENO Chain

What it shows:

- one `MOVE` on `powerRail`
- one second `MOVE` enabled by the first `MOVE.eno`
- one explicit `signalSource` reference between actions

Typical use:

- status copy networks
- sequential data moves that should stay in one LAD network
- maintenance-facing logic where one move should run only if the first move enables cleanly

Validation note:

- the underlying pattern was validated on July 22, 2026 against a real project clone flow
- accepted gate: `ImportExitCode=0`, `CompileExitCode=0`, `ExportExitCode=0`
