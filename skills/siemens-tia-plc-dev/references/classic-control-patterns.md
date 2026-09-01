# Classic Control Patterns

Use this reference when Codex needs to write practical Siemens PLC logic that feels like ordinary code work rather than one-off XML surgery.

## What changed in this skill

The current working rule set is based on three combined inputs:

- Siemens programming guidance for S7-1200 and S7-1500
- Siemens basic control libraries and application examples
- Siemens Openness and generation-oriented tooling examples
- validated local Codex runs that compiled imported sources end to end

This means the preferred authoring path is now:

1. write or refine block logic as source
2. keep each device pattern small and explicit
3. compile early on a safe project copy
4. promote good patterns into reusable examples

Official-source anchors behind this reference:

- the Siemens S7-1200/S7-1500 programming guideline for symbolic, modular, interface-driven structure
- Siemens Library of Basic Controls for reusable starter and drive-adjacent control patterns
- Siemens TIA Portal Openness code snippets and the Modular Application Creator direction for source- and model-driven engineering

## Core authoring rules

- Keep `OB1` thin. Use it as an orchestrator that calls device or sequence blocks rather than as the place where all plant logic lives.
- Prefer symbolic names and grouped state over scattered absolute addresses.
- Separate command, state, permissive, and fault signals even in small demos.
- For fast project demos, a global DB-backed `FC` is acceptable.
- For reusable library-grade logic, prefer an `FB` plus instance data or typed interfaces over hard-wired global DB access.
- Add only one new behavior step at a time, then compile and read back the result.
- When free-writing LAD is too narrow, step up one level and generate through SCL source plus Openness external-source import.

## Source import rules learned from validation

- When external sources include both block sources and dependent DB sources, generate block sources first and DB sources after them.
- Instance DB sources that point to an `FB` will fail if that `FB` has not already been generated in the same import run.
- In SCL, IEC timer calls such as `"TimerDb".TON(...)` need an explicit timer instance DB source. Do not assume Openness source generation will auto-create it for you.
- For compile-friendly demo projects, naming the timer DBs explicitly keeps the generated engineering objects predictable and easy to diff.
- For parent `FB` plus instance DB plus `OB1` call chains, a stable route is: generate structural sources in dependency order, generate the dependent DB sources, then do the final compile. Skip the intermediate compile when pending DB creation would make `OB1` fail only because the tags do not exist yet.

## Canonical patterns to keep ready

### Reversing starter

Intent:
One motor, two directions, mutual exclusion, stop, overload permissive.

Minimum state split:

- commands: `StartForward`, `StartReverse`, `Stop`
- permissive: `OverloadOK`
- internal: `ForwardLatch`, `ReverseLatch`
- outputs: `Q_Forward`, `Q_Reverse`

Checklist:

- forward and reverse must never energize together
- stop clears both latches
- overload loss clears both latches
- one direction request must cancel the other

### Manual/auto conveyor

Intent:
Manual jog or latched manual run, plus auto request path, sensor stop, overload and reset.

Minimum state split:

- mode: `ManualMode`, `AutoMode`
- commands: `StartPB`, `StopPB`, `AutoRequest`, `ResetFault`
- permissive: `OverloadOK`, `ExitSensorBlocked`
- internal: `ManualLatch`, `FaultLatched`
- output: `Q_Run`

Checklist:

- fault latches on overload loss
- reset only clears fault when permissive is healthy again
- manual latch drops on stop or mode loss
- auto path is gated by mode and downstream permissives

### Cylinder step with timeout

Intent:
Command a cylinder, verify feedback, raise timeout alarm if feedback is missing.

Minimum state split:

- commands: `ExtendCmd` or `RetractCmd`
- permissive: `AutoRun`
- feedback: `ExtendedLS`, `RetractedLS`
- timer path: `TON`
- alarms: `ExtendTimeout`, `RetractTimeout`

Checklist:

- the timer input is built from command true plus feedback not yet reached
- timeout alarm is driven by timer `Q`
- `ET` can be left open if not needed
- the exact wire shape should stay anchored to exported TIA XML when writing LAD directly

### Alarm latch with ack/reset

Intent:
Persist an alarm after a bad condition, then clear only when acknowledged and healthy.

Minimum state split:

- trigger: `FaultCondition`
- commands: `Ack`, optionally `Reset`
- internal: `AlarmLatched`
- output: `AlarmActive`

Checklist:

- set on condition
- clear only on operator action plus healthy condition
- do not clear just because the trigger flickers away

### CASE sequence station

Intent:
Drive a small automatic station through explicit steps such as feed, clamp, pick, and release.

Minimum state split:

- commands: `AutoStart`, `StopCmd`, `ResetCmd`
- feedback: `PartPresent`, `ClampClosed`, `PickDone`, `ReleaseDone`
- outputs: `ConveyorRun`, `ClampCmd`, `PickCmd`, `ReleaseCmd`
- internal: `Step`, `Busy`, `Complete`

Checklist:

- reset and stop must drive the sequence back to a known state
- outputs should be assigned from the active step, not left from older cycles
- each transition should be explicit and readable
- `CASE` is the preferred first step before graduating to GRAPH or larger unit-control frameworks

### Star-delta starter with UDT and FB

Intent:
Package one classic starter into a reusable block with structured I/O, timed star-to-delta transfer, and run-feedback supervision.

Minimum state split:

- command and feedback bundle in one UDT
- reusable logic in one `FB`
- instance memory in one instance DB
- internal timing via `TON` multi-instances

Checklist:

- keep field I/O grouped in a UDT when the device should scale to multiple copies
- keep sequencing and timers inside the `FB`, not in `OB1`
- ensure source import order is `UDT -> FB -> instance/global DB`
- supervise transition to running with explicit feedback timeout

### Multi-instance device cell

Intent:
Bundle several reusable child devices under one parent `FB` without creating extra top-level instance DB clutter.

Minimum state split:

- child device UDTs exposed on the parent block interface
- child device `FB`s declared as static members of the parent `FB`
- one parent instance DB holding the complete local instance data

Checklist:

- declare child `FB`s in the parent static section
- call child blocks by their local instance names
- prefer this pattern when a cell naturally contains a small fixed number of repeated devices
- use it to reduce object count and keep encapsulation local to the cell block

### Station supervisor with grouped UDTs and child alarms

Intent:
Wrap one station in a grouped I/O UDT, add child alarm latches for each fault class, and drive the station sequence through one parent `FB`.

Minimum state split:

- command group: `AutoStart`, `StopCmd`, `ResetCmd`, `AckCmd`
- fault group: `MotorFault`, `ConveyorFault`, `CylinderFault`, `SafetyFault`
- feedback group: `PartPresent`, `ClampClosed`, `PickDone`, `ReleaseDone`, `PermissiveOK`
- status group: `AnyFault`, per-group alarms, `AlarmActive`, `Ready`, `Busy`, `Running`, `Complete`

Checklist:

- compute grouped fault summary before the station sequence runs
- latch each fault class separately, then also latch the aggregate station alarm
- gate the child sequence with `Ready` so the station stops cleanly on fault loss
- keep `OB1` thin and let one parent `FB` own the station behavior

### Operating mode manager plus material handling cell

Intent:
Add one reusable mode layer above a station or cell so manual and auto behavior, permissives, starter control, and grouped fault handling stay in one readable parent block.

Minimum state split:

- mode group: manual select, auto select, start, stop, reset, ack, ready, motion enable
- cell commands: auto cycle request plus manual jog and actuator commands
- permissives: safety, air, local enable, process permissive
- packaged child devices: station supervisor and reusable starters
- grouped state: running, cycle complete, per-device faults, jam alarm, cycle counter

Checklist:

- keep mode logic in its own small `FB` so it can be reused outside the first cell
- keep the parent cell block interface grouped and human-readable
- map raw permissives into one mode block before driving manual or auto outputs
- drive child starter `FB`s through structured I/O instead of direct scattered tags
- use one parent `FB` to aggregate manual behavior, automatic sequence behavior, and grouped alarms
- when the pattern grows wider than a simple ladder edit, prefer `SCL + Openness import` and keep LAD focused on maintenance-facing surfaces

### Analog scaling and alarm conditioning

Intent:
Normalize one raw analog value, scale it into engineering units, clamp it, and generate readable alarm thresholds and control deviations.

Minimum state split:

- raw range: `RawInputCount`, `RawMinCount`, `RawMaxCount`
- engineering range: `EngMinValue`, `EngMaxValue`
- control target: `AutoSetpoint`, `MaintenanceSetpoint`, `ActiveSetpoint`
- condition outputs: `HighAlarm`, `LowAlarm`, `DeviationWarning`

Checklist:

- normalize first, then clamp, then scale
- clamp operator-facing setpoints to the same engineering range as the process value
- keep a substitute value path for unhealthy sensors
- keep alarm thresholds symbolic and easy to retune

### Status-word and command-word packing

Intent:
Pack symbolic machine state into one status word and decode one received command word without falling back to scattered absolute-bit logic.

Minimum state split:

- state bits: `SafetyOk`, `Ready`, `Running`, `FaultActive`
- command source selection: `LocalRunRequest`, `RemoteRunRequest`, `RemoteControlSelected`
- packed words: `StatusWord`, `CommandWord`
- decoded commands: `StartCmd`, `StopCmd`, `ResetCmd`

Checklist:

- rebuild the outgoing word from symbolic states every scan
- keep recipe or mode nibbles range-limited before packing
- use symbolic masks and shifts instead of hard-coded memory addresses
- decode inbound command bits into named booleans before using them in sequence logic

## Pattern selection guide

- Choose `SCL source + Openness import` for new logic blocks, demos, algorithmic edits, and anything wider than a tiny ladder rung.
- Choose `LAD XML patching` when the target must stay in ladder form and the structure already exists in exported XML.
- Choose `write-lad-batch` when several small ladder networks of the same block need deterministic edits.

## Current validated examples

The skill now carries four small source-backed examples:

- `examples/classic-scl/motor-fwd-rev`
- `examples/classic-scl/conveyor-auto-manual`
- `examples/classic-scl/cylinder-timeout-fc`
- `examples/classic-scl/alarm-latch-fb`
- `examples/classic-scl/sequence-station-fb`
- `examples/classic-scl/star-delta-starter-fb`
- `examples/classic-scl/dual-starter-cell-fb`
- `examples/classic-scl/station-supervisor-fb`
- `examples/classic-scl/material-handling-cell`
- `examples/classic-scl/analog-scaling-fc`
- `examples/classic-scl/status-word-builder-fc`

Treat these as seed patterns. They are intentionally compact, compile-friendly, and easy to adapt before being promoted to library-grade `FB` patterns.

The current training level is now split across two tiers:

- demo tier: `FC + global DB` for quick project bring-up
- reusable tier: `FB + instance DB + explicit dependencies` for blocks that should start looking like a library
