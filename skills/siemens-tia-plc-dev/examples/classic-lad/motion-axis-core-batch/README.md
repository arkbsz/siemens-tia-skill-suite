# Motion Axis Core Batch

What it shows:

- one batch rewrite across five motion-control LAD networks
- `MC_Halt`, `MC_Reset`, `MC_Home`, `MC_MoveJog`, and `MC_MoveAbsolute`
- condition-driven calls, action-only calls, and OR-branch motion calls in one block

Typical use:

- axis-control helper FCs
- motion bring-up blocks that collect stop, reset, home, jog, and move commands
- reviewable batch edits where several related networks should compile together

Validation note:

- the underlying pattern was validated on July 22, 2026 against a real project clone flow
- accepted gate: `ImportExitCode=0`, `CompileExitCode=0`, `ExportExitCode=0`
