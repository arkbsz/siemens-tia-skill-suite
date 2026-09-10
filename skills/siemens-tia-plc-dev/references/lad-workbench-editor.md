# Native LAD Workbench Editor

The Windows Forms workbench exposes a real LAD authoring loop under `LAD结构编辑`. It edits exported artifacts and never mutates TIA's internal binary project storage directly.

## Working Loop

1. Load a project and run `read-cycle` or select an exported LAD XML in the project tree.
2. Open `LAD结构编辑` and confirm the `网络` index.
3. Use `从XML读取` for a best-effort reconstruction of common contacts, compares, coils, timers, MOVE and counter shapes.
4. Add or remove entries in `条件链 / Conditions` and `动作链 / Actions`.
5. Click `结构生成JSON`, or edit the right-hand `LAD JSON` directly for branches, named CALL parameters, `signalSource`, array components, scopes, and other supported fields.
6. Save the JSON. The workbench writes to `PLC_Code\lad-editor\latest-network.json` and preserves an earlier copy under the editor backup folder.
7. Click `生成XML`. The workbench calls `write-lad-network` with the selected exported block as the target and writes `PLC_Code\lad-editor\latest.generated.xml`.
8. Click `校验XML` and inspect the command log. A successful validator result is necessary but not sufficient for TIA compile acceptance.
9. Click `克隆验证`. The generated XML is sent through `write-cycle`, which keeps production writes behind backup, clone import, compile, re-export and evidence gates.

## Structured Fields

The compact editor supports:

- `NO`, `NC`, `P_EDGE`, `N_EDGE`
- `EQ`, `NE`, `GE`, `GT`, `LE`, `LT` with symbols or literal operands
- `COIL`, `SET`, `RESET`
- `TON`, `TOF`, `TP`
- `MOVE` using `source -> target` or source in the instance field
- `CTU`, `CTD`, `CTUD`
- `CALL` with a block name and optional instance; use JSON for named inputs/outputs

The list editor intentionally covers the common maintenance-facing path. It does not pretend to reverse every graphical property of every TIA instruction. For uncommon shapes, retain the XML as the source of truth and use direct JSON, donor network patching, SCL source import, or technology-object routing.

## Safety And Evidence

- The target XML is an exported text artifact, not a production project binary.
- Overwriting the editor JSON or generated XML creates a timestamped backup first.
- `write-lad-network` does not import into TIA by itself.
- `write-cycle` is the default gate for clone import and compile; it does not download to a PLC.
- If Openness readiness is false, stop live clone work and continue with XML/SCL authoring until the Windows logon session is repaired.
