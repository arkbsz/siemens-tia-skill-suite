# EQ TON Set

What it shows:

- one compare condition against a step value
- follow-up permissive contacts in the same series rung
- one `TON` and one `SET` action driven from the validated signal path

Typical use:

- step-based alarm timing
- sequence phase timeout checks
- maintenance-facing alarm logic that should stay in LAD

Validation note:

- the underlying pattern was validated on July 22, 2026 against a real project clone flow
- accepted gate: `ImportExitCode=0`, `CompileExitCode=0`, `ExportExitCode=0`
- reuse an existing timer instance DB in the target project, or provision one under `supporting-sources`
