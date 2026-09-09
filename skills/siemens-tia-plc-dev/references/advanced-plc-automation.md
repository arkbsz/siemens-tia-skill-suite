# Advanced PLC Automation

Use this reference when a program needs more than classic permissives, latches, timers and counters.

## Instruction Family Routing

Choose the implementation surface by instruction family:

- operator-facing logic: LAD JSON or donor LAD network
- timers, counters, compares and interlocks: LAD JSON first
- motion, drives, communication and library FBs: generic `CALL` with named pins and reviewed instance DB strategy
- analog scaling, numeric conditioning, bit packing, conversion, strings, arrays and recipes: SCL source import
- unsupported LAD box shapes: export a donor network from TIA, patch `NetworkSource` / `FlgNet`, then verify on a clone

Do not force every instruction into direct LAD JSON. A mixed LAD/SCL/CALL project is usually more maintainable than a visually dense ladder block.

Before authoring a mixed or advanced change, run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" plc-instruction-plan -ProjectPath "D:\path\to\project" -TaskText "task"
```

This creates `PLC_Code\plc\instruction-plans\latest\instruction-route-table.md/json`, `technology-object-plan.md`, and `safety-risk-assessment.md`. Treat the route table as the contract between the Agent, the LAD/SCL generators, Openness import and the workbench review panels.

## Technology Objects

When technology objects or motion instructions are involved:

- identify CPU family, firmware and TIA version first
- identify technology object names, axis type, drive interface and generated DBs
- keep enable, reset, home, jog, move and stop commands separate from feedback and diagnostics
- use `MC_Power`, `MC_Reset`, `MC_Home`, `MC_MoveAbsolute`, `MC_MoveRelative`, `MC_MoveVelocity`, `MC_Halt` and vendor blocks as typed calls instead of ad hoc bit logic
- add explicit mode, authority and safe-stop assumptions to the risk review
- verify whether the target change requires CPU stop/download restrictions before planning online application

## Communication Blocks

For Modbus, TCP, serial or drive communication:

- treat connection/load blocks and cyclic request blocks as separate networks
- keep `REQ`, `BUSY`, `DONE`, `ERROR`, `STATUS` and retry timing visible in LAD when possible
- store addresses, lengths, modes and timeout parameters in a parameter DB
- use SCL for frame parsing, word swapping, float conversion and array copies
- always expose communication health, last status word, retry count and stale-data alarm to HMI

`MB_COMM_LOAD`, `MB_MASTER`, `MB_CLIENT` and `MB_SERVER` should normally be generated as named `CALL` actions with DB-backed parameters.

## Naming

Use concise bilingual names:

- blocks: `FC_输送线_Conveyor`, `FB_轴控制_AxisControl`, `DB_参数_Parameters`
- variables: `启动命令_StartCmd`, `运行反馈_RunFb`, `故障状态_FaultSts`, `互锁允许_InterlockOk`
- HMI objects: `BTN_复位_Reset`, `IND_运行_Running`, `FP_电机_Motor`

Keep the Chinese part short and concrete; keep the English part stable for search and integration.

## Safety Risk Review

Every advanced PLC task should produce or update a risk note when it touches:

- motion enable, reset, home, jog or move commands
- drives and communication commands
- recipe/parameter writes
- manual/automatic mode transfer
- alarm acknowledgement, reset or force-like actions
- HMI command authority

The AI may assist with interlock coverage and command consistency, but certified safety functions still require the project's safety engineering workflow.

## Source Anchors

- Siemens S7-1200/S7-1500 programming guideline, Entry ID `81318674`
- Siemens S7-1200/S7-1500 instruction family documentation on `docs.tia.siemens.cloud`
- Siemens TIA Portal Openness overview, Entry ID `109792902`
- Siemens official TIA Portal Openness code snippets on GitHub
- Siemens S7-1500 Motion Control documentation on `docs.tia.siemens.cloud`, including `MC_Power`, `MC_Reset`, `MC_Home`, `MC_Halt`, `MC_MoveAbsolute`, `MC_MoveRelative`, `MC_MoveVelocity`, `MC_MoveJog`, `MC_Stop`, parameter write and measuring/cam instructions
- current project exports and compile logs
