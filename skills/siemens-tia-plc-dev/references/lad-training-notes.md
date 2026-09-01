# LAD Training Notes

Current ladder lessons:

- Read real exported LAD first, then write back through `NetworkSource` / `FlgNet`.
- Keep each network to one visible behavior when possible.
- Prefer clear names like `StartCmd`, `StopCmd`, `RunCmd`, `FaultActive`.
- For interface members in an FC or FB, set `scope` to `LocalVariable` in the network JSON.
- Use short titles and comments that explain intent, not syntax.
- When a rung becomes algorithmic, move that logic to SCL and keep LAD as the readable operator-facing layer.
- When the network JSON contains Chinese symbol names on Windows PowerShell, read the spec as UTF-8 explicitly before `ConvertFrom-Json`. Do not rely on the default file encoding.
- `write-lad-network` now reports `TonInstancesSeenInTargetXml` and `TonInstancesMissingFromTargetXml` to warn when a `TON` action points to an instance path not already seen in the target block XML.
- `TON.pt` can now be authored either as a plain time string such as `T#1s` or as a symbol/components operand that resolves to a `TIME` variable.
- A real-project free-write validation exists for `FC1_报警程序块` network 15 in a production-style TIA project, and it passed clone import, compile, and post-import export with `ImportExitCode=0`, `CompileExitCode=0`, and `ExportExitCode=0` on July 22, 2026.
- A real-project `TON + SET` validation exists for `fc1-conveyor-jam-ton-reuse-instance.generated.xml`, and it passed clone import, compile, and post-import export with `ImportExitCode=0`, `CompileExitCode=0`, and `ExportExitCode=0` on July 22, 2026.
- A real-project multi-action `RESET/SET` fanout validation exists for `fc1-reset-fanout-freewrite.generated.xml`, and it passed clone import, compile, and post-import export with `ImportExitCode=0`, `CompileExitCode=0`, and `ExportExitCode=0` on July 22, 2026.
- A `TON` spec that referenced a new timer instance name `IEC_Timer_0_DB_4` imported but failed compile with `Missing instance DB` on July 22, 2026.
- The same `IEC_Timer_0_DB_4` case then passed end to end after `verify-lad-change` auto-imported `supporting-sources\IEC_Timer_0_DB_4.db` into the clone before the XML block import.
- A batch case that rewrote `FC1_报警程序块` networks 14 and 15 together also passed end to end on July 22, 2026 with `ImportExitCode=0`, `CompileExitCode=0`, and `ExportExitCode=0`.
- Current safe route for timer-backed free-write: reuse an existing timer instance already present in the project, or place a matching `IEC_TIMER` DB source under `supporting-sources` beside the generated XML.
- When a change introduces a new source-generated DB that later LAD blocks reference, import that source with `import-sources --compile --save` before reopening the project or importing the dependent blocks; otherwise the generated object can exist only in the transient session and the next compile will report `Tag ... not defined`.
- A real-project validation now exists for the July 24, 2026 industrialization-and-simulation upgrade on a production-style TIA project: the clone and the main project both passed `source import -> block import -> compile -> LAD export readback`, including `FC6_StationSupervisor` with `TON(PT=DB_6StationState.AutoStepTimeoutSetpoint_自动步超时设定)` and the new `FC7_SimulationIO` LAD block.

- A real-project OR-branch validation exists for `fc4-manual-auto-or-branch.generated.xml`, and it passed clone import, compile, and post-import export with `ImportExitCode=0`, `CompileExitCode=0`, and `ExportExitCode=0` on July 22, 2026.
- The validated OR-branch shape is: powerrail fanout to each branch head, series contacts per branch, `Part Name="O"` with `TemplateValue Name="Card"`, then one downstream coil or timer path.
- `summarize-lad` should read that exported shape back as grouped logic, for example `(manual branch) OR (auto branch)`, so the read path stays aligned with the write path.
- A real-project compare-condition validation exists for `fc1-eq-ton-set-freewrite.generated.xml`, and it passed clone import, compile, and post-import export with `ImportExitCode=0`, `CompileExitCode=0`, and `ExportExitCode=0` on July 22, 2026.
- The validated compare shape is: signal flow into compare input `pre`, operand wires into `in1` and `in2`, `TemplateValue Name="SrcType"`, then downstream contacts or timer logic.
- A real-project compare-plus-move validation exists for `fc5-eq-move-freewrite.generated.xml`, and it passed clone import, compile, and post-import export with `ImportExitCode=0`, `CompileExitCode=0`, and `ExportExitCode=0` on July 22, 2026.
- A real-project set-plus-move validation exists for `fc5-set-move-freewrite.generated.xml`, and it passed clone import, compile, and post-import export with `ImportExitCode=0`, `CompileExitCode=0`, and `ExportExitCode=0` on July 22, 2026.
- The validated `MOVE` shape is: signal path into `en`, value source into `in`, and one target variable on `out1`.
- When `MOVE` shares the same source condition path with `SET`, `RESET`, or `COIL`, use one shared source wire that fans out to all immediate targets. Emitting several independent wires from the same source output caused import failure before the fanout fix.
- A real-project `CTU` validation exists for `fc5-ctu-reset-freewrite.generated.xml`, and it passed clone import, compile, and post-import export with `ImportExitCode=0`, `CompileExitCode=0`, and `ExportExitCode=0` on July 22, 2026.
- The validated `CTU` shape is: one `CU` signal path, one independent `R` signal path, one `PV` access, one counter instance DB, and one open `CV` connection when the current value is not consumed in the same network.
- On August 30, 2026, the skill documentation was expanded to treat Siemens instruction coverage as a routing problem instead of a single-LAD-JSON problem.
- The new route is:
  - direct LAD JSON for bit logic, compares, timers, and counters
  - generic `CALL` for motion, communication, drive, and technology/library blocks
  - SCL source import for arithmetic, conversion, string, array, and bulk data handling
  - donor-network patching when a ladder box shape is still missing from the JSON writer
- The LAD JSON writer now also models `TOF`, `TP`, `CTD`, and `CTUD` at the XML-generation layer.
- Until clone compile validation is recorded on a real project, treat `TOF`, `TP`, `CTD`, and `CTUD` as supported-but-not-yet-project-validated shapes.
- On August 30, 2026, `verify-lad-change-on-clone.ps1` was adjusted to default its clone workspace under `PLC_Code\verification\_clones` so it works in workspace-restricted environments.
- The same verification script now prints step progress for clone, import, compile, and export so long Openness waits do not look like a dead session.
- If a verification run creates the clone directory but still produces no TIA/compile progress, stop waiting blindly and switch to stepwise diagnostics instead of assuming the instruction XML itself is wrong.
- `P_EDGE` needs both the live operand symbol and a separate edge-memory symbol wired to `bit`.
- A mixed-path network such as `CTU` should still use one shared `Powerrail` wire for all root branches. Multiple separate `Powerrail` wires in one generated network caused import failure before the fix.
- A real-project `MC_Power` validation exists for `fc2-mc-power-freewrite.generated.xml`, and it passed clone import, compile, and post-import export with `ImportExitCode=0`, `CompileExitCode=0`, and `ExportExitCode=0` on July 22, 2026.
- The validated `MC_Power` shape is: `Powerrail -> MC_Power.en` and `Contact.in`, then `Contact.out -> MC_Power.Enable`, with named inputs and open outputs.
- A real-project action-only `MB_COMM_LOAD` validation exists for `fc3-mb-comm-load-freewrite.generated.xml`, and it passed clone import, compile, and post-import export with `ImportExitCode=0`, `CompileExitCode=0`, and `ExportExitCode=0` on July 22, 2026.
- The validated `MB_COMM_LOAD` shape is: action-only `CALL` plus `powerRail`, `REQ` from a symbol, `PORT` from `GlobalConstant`, scalar literal inputs, and a mix of open and mapped outputs.
- A real-project `MB_MASTER + MOVE` validation exists for `fc3-mb-master-readfreq-freewrite.generated.xml`, and it passed clone import, compile, and post-import export with `ImportExitCode=0`, `CompileExitCode=0`, and `ExportExitCode=0` on July 22, 2026.
- The validated `MB_MASTER` shape is: compare signal into `REQ`, `powerRail` into both `MB_MASTER.en` and a parallel `MOVE.en`, array-style `components` access for `DATA_PTR`, and one separate array-style source for `MOVE.in`.
- Use `components` when a symbol path needs nested XML under one component, especially `AccessModifier="Array"` plus a literal index access.
- A generated `MB_MASTER` network failed import before `MOVE` was allowed to sit on `powerRail`; the import passed once the generated root wire matched the real exported branch layout.
- A real-project batch motion validation exists for `fc2-motion-batch-freewrite.generated.xml`, and it passed clone import, compile, and post-import export with `ImportExitCode=0`, `CompileExitCode=0`, and `ExportExitCode=0` on July 22, 2026.
- The validated FC2 batch covers `MC_Halt`, `MC_Reset`, `MC_Home`, `MC_MoveJog`, and `MC_MoveAbsolute` in one compile-safe block rewrite.
- The validated `MC_Home` shape is: one contact path into `Execute`, `powerRail` into `en`, `Axis` plus `Mode` as mapped inputs, and open outputs including `ReferenceMarkPosition`.
- The validated `MC_MoveJog` shape is: action-only `CALL` with `powerRail`, one axis input, two jog direction inputs, one velocity input, one open `PositionControlled` input, and open status outputs.
- The validated `MC_MoveAbsolute` shape is: four OR-ed start contacts into `Execute`, one shared `powerRail` wire into both the branch heads and `en`, one axis input, and open motion-parameter inputs such as `Position`, `Velocity`, and `Direction`.
- A real-project dual-`MOVE` validation exists for `fc2-status-dual-move-freewrite.generated.xml`, and it passed clone import, compile, and post-import export with `ImportExitCode=0`, `CompileExitCode=0`, and `ExportExitCode=0` on July 22, 2026.
- The validated dual-`MOVE` shape is: first `MOVE` on `powerRail`, second `MOVE` enabled by `signalSource { actionIndex: 1, name: "eno" }`, with separate `out1` target mappings.
- A real-project shared-prefix branch validation exists for `fc2-homing-branch-freewrite.generated.xml`, and it passed clone import, compile, and post-import export with `ImportExitCode=0`, `CompileExitCode=0`, and `ExportExitCode=0` on July 22, 2026.
- The validated shared-prefix branch shape is: one common prefix path, one multi-target wire from that prefix output to the downstream compare `pre` inputs, then separate action paths such as `NE -> COIL` and `EQ -> MOVE`.
- The first shared-prefix branch import failed when the generated XML used two separate source wires from the same prefix output. TIA accepted the network only after those downstream `pre` targets were merged onto one shared wire.
- A real-project full FC2 batch validation exists for `fc2-full-step-block-freewrite.generated.xml`, and it passed clone import, compile, and post-import export with `ImportExitCode=0`, `CompileExitCode=0`, and `ExportExitCode=0` on July 22, 2026.
- The validated full FC2 batch covers networks 1 through 16 with motion calls, status copies, four position command branches, and a multi-step homing sequence in one compile-safe rewrite.
- A real-project mixed direct-plus-branch validation exists for `network16.generated.xml` under `fc5-sequence-branch-ton-batch`, and it passed clone import, compile, and post-import export with `ImportExitCode=0`, `CompileExitCode=0`, and `ExportExitCode=0` on July 22, 2026.
- The validated mixed direct-plus-branch shape is: one shared prefix path, one direct coil on that prefix, one shared fanout wire to the downstream compare `pre` inputs, and one branch `MOVE` path that advances the sequence step.
- A real-project `TON + MOVE` validation exists for `network27.generated.xml` under `fc5-sequence-branch-ton-batch`, and it passed clone import, compile, and post-import export with `ImportExitCode=0`, `CompileExitCode=0`, and `ExportExitCode=0` on July 22, 2026.
- The validated `TON + MOVE` step shape is: sequence condition path into `TON.IN`, typed constant `PT`, reused instance DB, then `TON.Q -> MOVE.en` and one literal step value into `MOVE.in`.
- A real-project FC5 sequence batch validation exists for `fc5-sequence-branch-ton-batch.generated.xml`, and it passed clone import, compile, and post-import export with `ImportExitCode=0`, `CompileExitCode=0`, and `ExportExitCode=0` on July 22, 2026.
- The validated FC5 batch covers one mixed branch-driven motion step plus two timer-driven step transitions in the automatic sequence block.
- A real-project full FC5 automatic-block batch validation exists for `fc5-full-automatic-block-freewrite.generated.xml`, and it passed clone import, compile, and post-import export with `ImportExitCode=0`, `CompileExitCode=0`, and `ExportExitCode=0` on July 22, 2026.
- The validated full FC5 batch covers all 36 networks of the automatic sequence block, including auto-start seal-in, stop latching, single-step counter logic, repeated set/reset actuator steps, shared-prefix motion branches, and timer-driven dwell transitions.
- A practical scaffold route now exists for large Chinese-symbol projects: read a verified ladder summary, harvest symbol names from that summary, reuse a few proven JSON templates, and emit batch specs through an ASCII-safe generator so Windows PowerShell encoding does not corrupt the source symbols.
- When parity with the live project matters more than cleanup, preserve exported quirks explicitly in the generated specs and note them in comments; on the July 22, 2026 FC5 full-batch run, network 15 intentionally kept the exported step return behavior instead of silently "fixing" it.
- On September 1, 2026, a local `probe` on `D:\plc\手动程序\手动程序.ap17` showed `ConfiguredInSiemensTiaOpennessGroup = true` but `ActiveInCurrentLogonToken = false`, and a live `list-plcs` attempt failed with `Connection to TiaPortal failed`. Treat that combination as a session-level Openness prerequisite failure and stop before clone/import/compile; tell the user to fully sign out of Windows and sign in again, then rerun `probe` or `doctor`.

Useful case studies:

- `skill_demo_start_stop` start/stop export
- `Main.generated.xml` free-write sample
- `fc1-feed-sensor-alarm-freewrite.generated.xml` on the real `手动程序` alarm block
- `fc1-conveyor-jam-ton-reuse-instance.generated.xml` for validated `TON + SET`
- `fc1-reset-fanout-freewrite.generated.xml` for validated multi-action fanout
- `fc1-conveyor-jam-ton-freewrite.generated.xml` for validated new timer instance plus `supporting-sources`
- `fc1-batch-reset-plus-ton.generated.xml` for validated multi-network batch plus `supporting-sources`
- `fc4-manual-auto-or-branch.generated.xml` for validated OR-branch ladder generation
- `fc1-eq-ton-set-freewrite.generated.xml` for validated compare-plus-timer ladder generation
- `fc5-eq-move-freewrite.generated.xml` for validated compare-plus-move ladder generation
- `fc5-set-move-freewrite.generated.xml` for validated set-plus-move ladder generation
- `fc5-ctu-reset-freewrite.generated.xml` for validated counter-plus-reset ladder generation
- `fc2-mc-power-freewrite.generated.xml` for validated motion-control function block calls
- `fc3-mb-comm-load-freewrite.generated.xml` for validated action-only communication block calls
- `fc3-mb-master-readfreq-freewrite.generated.xml` for validated communication block calls with array-style operands and a parallel `MOVE`
- `fc2-motion-batch-freewrite.generated.xml` for validated multi-network motion-control ladder generation
- `fc2-status-dual-move-freewrite.generated.xml` for validated chained-`MOVE` ladder generation
- `fc2-homing-branch-freewrite.generated.xml` for validated shared-prefix branch ladder generation
- `fc2-full-step-block-freewrite.generated.xml` for validated full FC2 step-block ladder generation
- `fc5-sequence-branch-ton-batch.generated.xml` for validated FC5 automatic-sequence ladder generation
- `fc5-full-automatic-block-freewrite.generated.xml` for validated full FC5 automatic-block ladder generation

External anchors:

- Siemens Openness overview
- Siemens official Openness code snippets
- Siemens programming style guide
- Siemens Library of Basic Controls

Training loop:

1. summarize a real export
2. write a clean network spec
3. validate the XML
4. import into a clone
5. compile and save
6. capture the pattern back into the skill
