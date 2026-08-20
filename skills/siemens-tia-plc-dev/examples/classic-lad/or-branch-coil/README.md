# OR Branch Coil

What it shows:

- one manual branch and one auto branch merged into one output coil
- JSON `conditionGroups` mapped to a real LAD `O` part with branch inputs such as `in1` and `in2`
- the readable authoring path for classic manual/auto merge logic

Typical use:

- manual jog OR automatic request
- maintenance-facing output logic that should stay in LAD
- refactoring an existing parallel branch network without editing raw XML by hand

Validation note:

- the underlying branch shape was validated on July 22, 2026 against the real `D:\plc\手动程序` project clone flow
- accepted gate: `ImportExitCode=0`, `CompileExitCode=0`, `ExportExitCode=0`
