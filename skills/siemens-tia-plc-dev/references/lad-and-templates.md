# LAD And Templates

Use this when the task is about reading, generating, reviewing, or reusing ladder logic across projects.

## Read like code

Generate a block summary:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" summarize-lad -Path "D:\path\to\block.xml" -OutputPath "D:\path\to\block.lad.md"
```

Generate a project-wide catalog:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" build-lad-catalog -Path "D:\path\to\project\PLC_Code\ladders" -OutputPath "D:\path\to\project\PLC_Code\reports\lad-template-catalog.md"
```

## Build reusable templates

Export a single network as a template manifest:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" export-lad-template -SourceXml "D:\path\to\block.xml" -NetworkIndex 1 -OutputPath "D:\path\to\project\PLC_Code\templates\lad\my-template.template.json" -TemplateName "my-template"
```

Index saved templates:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" build-lad-index -Path "D:\path\to\project\PLC_Code\templates\lad" -OutputPath "D:\path\to\project\PLC_Code\templates\lad\template-index.md"
```

## Safe edit pattern

Apply a network-oriented replacement to a full block XML:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" apply-lad-template -SourceXml "D:\path\to\source.xml" -OutputXml "D:\path\to\generated.xml" -NetworkIndex 1 -Replace "Old=New;Old2=New2"
```

Then:

1. validate the XML
2. summarize the generated block
3. preview import
4. apply only to a backup project first
5. compile and save

## First free-write ladder path

Use this when you want to author a simple rung in structured JSON instead of touching XML directly:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" scaffold-lad-network-json -OutputPath "D:\path\to\network.json" -Title "Alarm rung"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" write-lad-network -TargetXml "D:\path\to\block.xml" -SpecPath "D:\path\to\network.json" -OutputXml "D:\path\to\generated.xml" -NetworkIndex 1
```

This first subset currently supports:

- `NO` and `NC` contacts in one series rung
- edge conditions `P_EDGE` and `N_EDGE`
- compare conditions `EQ`, `NE`, `GE`, `GT`, `LE`, `LT`
- one or more `conditionGroups` for OR branches
- shared-prefix `branches` for split downstream logic after one common condition path
- one signal path with optional `TON`
- one or more output actions
- output kinds `COIL`, `SET`, `RESET`, `TON`, `MOVE`, `CTU`, and generic `CALL`
- action-only `CALL` networks driven by `powerRail`
- `powerRail` on `MOVE` for an independent root branch in the same network
- `signalSource` on `MOVE` for chaining from an earlier action output such as `eno`
- `constantName` for `GlobalConstant` operands such as hardware constants
- `components` paths for array-style variable access
- title and comment text
- `scope` on symbols when the block uses local interface members

When `conditionGroups` is used, `write-lad-network` builds a real `O` part with the required `Card` value and branch wires such as `in1`, `in2`, and a powerrail fanout.

Compare condition shape:

```json
{
  "kind": "EQ",
  "sourceType": "Word",
  "left": { "symbol": "AutoStep" },
  "right": { "scope": "LiteralConstant", "constantType": "Word", "value": "10" }
}
```

Move action shape:

```json
{
  "kind": "MOVE",
  "source": { "scope": "LiteralConstant", "constantType": "Word", "value": "1" },
  "target": { "symbol": "AutoStep" }
}
```

When a `MOVE` shares one rung with `COIL`, `SET`, or `RESET`, the signal path should fan out through one shared source wire to the mixed targets rather than through several independent wires from the same output pin.

When a `MOVE` should sit on an independent root branch, add `powerRail: true` so its `en` input is driven directly from the network powerrail rather than from the condition signal path.

When a `MOVE` should be enabled by an earlier action output, use `signalSource`:

```json
{
  "kind": "MOVE",
  "signalSource": {
    "actionIndex": 1,
    "name": "eno"
  },
  "source": { "symbol": "Axis_1.ActualVelocity" },
  "target": { "symbol": "AxisSpeed" }
}
```

This pattern was validated against a real FC2 status network with `Move1.eno -> Move2.en`.

Shared-prefix branch shape:

```json
{
  "conditions": [
    { "kind": "NC", "symbol": "ManualAuto" },
    {
      "kind": "EQ",
      "sourceType": "UInt",
      "left": { "symbol": "HomeStep" },
      "right": { "scope": "LiteralConstant", "constantType": "UInt", "value": "2" }
    }
  ],
  "branches": [
    {
      "conditions": [
        {
          "kind": "NE",
          "sourceType": "Real",
          "left": { "symbol": "ActualPos" },
          "right": { "symbol": "TargetPos" }
        }
      ],
      "actions": [
        { "kind": "COIL", "symbol": "HomeJogCmd" }
      ]
    },
    {
      "conditions": [
        {
          "kind": "EQ",
          "sourceType": "Real",
          "left": { "symbol": "ActualPos" },
          "right": { "symbol": "TargetPos" }
        }
      ],
      "actions": [
        {
          "kind": "MOVE",
          "source": { "scope": "LiteralConstant", "constantType": "UInt", "value": "0" },
          "target": { "symbol": "HomeStep" }
        }
      ]
    }
  ]
}
```

Use `branches` when one shared prefix should fan out into several downstream compares or contacts that each drive their own action path. The validated FC2 homing pattern required one shared source wire from the prefix output to both downstream `pre` inputs, not several separate wires.

When the same shared prefix also drives one direct output action, keep that direct action on the same fanout wire as the downstream branch entry points. A later FC5 validation showed that TIA expected one shared source wire for `direct coil + branch pre + branch pre`, not one wire for the direct action and a second wire for the branch heads.

Call action shape:

```json
{
  "kind": "CALL",
  "partName": "MC_Power",
  "version": "8.0",
  "instance": "MC_Power_DB",
  "powerRail": true,
  "signalTarget": "Enable",
  "inputs": [
    { "name": "Axis", "symbol": "Axis_1" },
    { "name": "StartMode", "open": true },
    { "name": "StopMode", "open": true }
  ],
  "outputs": [
    { "name": "Error", "open": true }
  ]
}
```

Array-style component path shape:

```json
{
  "components": [
    { "name": "DriveDb" },
    {
      "name": "ReadBuffer",
      "accessModifier": "Array",
      "access": {
        "scope": "LiteralConstant",
        "constantType": "DInt",
        "value": "0"
      }
    }
  ]
}
```

Use `components` when the real exported XML shows nested `<Component ... AccessModifier="Array">` access, such as `MB_MASTER.DATA_PTR`.

Edge condition shape:

```json
{
  "kind": "P_EDGE",
  "symbol": "StartPulse",
  "bitSymbol": "StartPulseMemory"
}
```

CTU action shape:

```json
{
  "kind": "CTU",
  "instance": "StepCounterDb",
  "valueType": "Int",
  "pv": { "scope": "LiteralConstant", "constantType": "Int", "value": "1" },
  "resetConditionGroups": [
    { "conditions": [ { "kind": "NO", "symbol": "ResetCmd" } ] },
    { "conditions": [ { "kind": "GE", "sourceType": "Int", "left": { "symbol": "StepCounterDb.CV" }, "right": { "scope": "LiteralConstant", "constantType": "Int", "value": "31" } } ] }
  ]
}
```

For `CTU`, the current signal path feeds `CU`, while `resetConditionGroups` or `resetConditions` build a second signal path that feeds `R`. Use one shared network `Powerrail` source across both paths.

Validated call patterns:

- `MC_Power`: one condition path into `Enable`, plus `powerRail` into `en`
- `MB_COMM_LOAD`: action-only network with `powerRail`, `GlobalConstant`, and open inputs/outputs
- `MB_MASTER`: compare signal into `REQ`, array-style `components` access for `DATA_PTR`, and one `MOVE` branch on `powerRail`
- shared-prefix homing branch: one common compare path fans out to two downstream compares, one driving a `COIL` and one driving a `MOVE`
- mixed direct-plus-branch step: one common prefix path drives one direct `COIL`, one downstream compare that drives another `COIL`, and one downstream compare that drives a `MOVE`
- `TON + MOVE` step transition: one sequence condition path drives `TON.IN`, then `TON.Q` enables the step-advance `MOVE`

Use `verify-lad-change` on a cloned project after generation.

Important timer note:

- if a JSON spec uses `TON`, the referenced timer instance DB must already exist in the target project, or be provisioned separately before compile
- on the current `手动程序` project, a new instance such as `IEC_Timer_0_DB_4` imported successfully but failed compile with `Missing instance DB`
- reusing an existing timer instance already present in the target block was validated successfully on 2026-07-22
- `verify-lad-change` now auto-detects a sibling `supporting-sources` directory next to the generated XML and imports those source files into the clone before block import
- on July 22, 2026, the same `IEC_Timer_0_DB_4` case was validated successfully after adding `supporting-sources\IEC_Timer_0_DB_4.db` with `IEC_TIMER`

For naming and comments, prefer the same readable style used in `references/naming-and-comments.md`.

## Batch free-write ladder path

When a block needs several network edits in one pass, chain multiple JSON specs through a batch manifest:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" write-lad-batch -TargetXml "D:\path\to\block.xml" -ManifestPath "D:\path\to\batch-manifest.json" -OutputXml "D:\path\to\generated.xml"
```

Manifest shape:

```json
{
  "steps": [
    { "networkIndex": 7, "specPath": "D:\\path\\to\\network07.json" },
    { "networkIndex": 8, "specPath": "D:\\path\\to\\network08.json" }
  ]
}
```

This is the preferred path when one change request spans several LAD networks but should still compile as one reviewed block artifact.

Validated batch motion pattern:

- a five-network rewrite of one FC2 motion block was validated on July 22, 2026
- the batch covered `MC_Halt`, `MC_Reset`, `MC_Home`, `MC_MoveJog`, and `MC_MoveAbsolute`
- this is the preferred route when one machine function spans several small motion-control networks that should stay together during review

Validated full step-block batch pattern:

- a 16-network rewrite of the FC2 step block was validated on July 22, 2026
- the batch covered axis power, motion calls, status copies, position command branches, and the homing-step sequence
- this is the preferred route when one machine station block mixes motion, state, and operator-facing ladder in one compile unit set

Validated FC5 sequence batch pattern:

- a three-network rewrite of one FC5 automatic sequence block was validated on July 22, 2026
- the batch covered one mixed direct-plus-branch motion step and two `TON + MOVE` step transitions
- this is a good training slice for conveyor or transfer-station sequence logic where one block mixes motion state transitions and timer-controlled dwell steps

Validated full FC5 automatic-block pattern:

- a 36-network rewrite of the FC5 automatic sequence block was validated on July 22, 2026
- the batch covered auto-start sealing, stop latch logic, single-step counting, repeated cylinder set/reset steps, position-driven shared-prefix motion branches, and timer-driven dwell transitions
- this is the preferred route when one station block is wide enough to look like a real industrial sequence instead of a small demo rung set

Summary-driven scaffold pattern:

- for larger blocks, do not hand-author every network JSON from scratch
- first export and summarize the real LAD block, then harvest the symbol list and title of each network from that summary
- next reuse a small set of already validated JSON shapes such as `EQ + MOVE`, `SET + MOVE`, shared-prefix branch, mixed direct-plus-branch, and `TON + MOVE`
- emit the new specs through an ASCII-safe generator when the project uses Chinese symbols, then run `write-lad-batch` and the normal clone import / compile / export gate
- if one exported network appears logically questionable, preserve it deliberately for parity on the first full-block rewrite and document the behavior before attempting a functional cleanup batch

Batch plus supporting sources:

- if the generated batch XML needs new `TON` instance DBs or other helper sources, place them in a sibling `supporting-sources` directory next to the generated XML
- `verify-lad-change` will import that sibling source directory into the clone before it imports the batch XML block
- this route was validated on July 22, 2026 with one batch that rewrote `FC1_报警程序块` networks 14 and 15 while also importing `supporting-sources\IEC_Timer_0_DB_4.db`

Summary note:

- `summarize-lad` now reconstructs validated OR branches into readable expressions such as `(branch1) OR (branch2)` instead of leaving a raw trailing `O`
- `summarize-lad` now also resolves constant operands so compare networks read back as `Eq(in1=AutoStep, in2=10)` instead of dropping the literal side
- `summarize-lad` reads validated step-style networks back as `Move(in=1, out1=AutoStep)` so compare plus move edits stay readable after export
- `summarize-lad` now reads validated counter networks back with separate trigger and reset paths, for example `CU=(...) ; R=(...)`
- `summarize-lad` now also reads validated generic calls such as `MC_Power`, `MB_COMM_LOAD`, and `MB_MASTER` back as named-argument operations
- `summarize-lad` now reads shared-prefix branch networks back as separate `BRANCH IF ... THEN ...` lines when one upstream path splits into different downstream actions
- `summarize-lad` now also reads mixed direct-plus-branch networks back as multiple `BRANCH IF ... THEN ...` lines, including the direct action that shares the upstream prefix

## Faster single-change loop

If you want one ladder modification to feel more like a normal source-code task, scaffold a dedicated change package:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" scaffold-lad-change -ProjectPath "D:\path\to\project" -SourceXml "D:\path\to\block.xml" -ChangeName "vacuum-alarm-refactor"
```

Then verify the generated XML end to end on a cloned project:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" verify-lad-change -ProjectPath "D:\path\to\project" -InputXml "D:\path\to\project\PLC_Code\changes\vacuum-alarm-refactor\outputs\vacuum-alarm-refactor.generated.xml" -PlcName "PLC_1"
```
