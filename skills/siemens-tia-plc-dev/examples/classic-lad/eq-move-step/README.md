# EQ Move Step

What it shows:

- one step compare against a literal value
- one permissive contact in series
- one `MOVE` action that advances the step variable

Typical use:

- simple step sequencers
- state advance when one phase condition is satisfied
- readable LAD around a step variable without switching to SCL

Validation note:

- the underlying pattern was validated on July 22, 2026 against the real `D:\plc\手动程序` project clone flow
- accepted gate: `ImportExitCode=0`, `CompileExitCode=0`, `ExportExitCode=0`
