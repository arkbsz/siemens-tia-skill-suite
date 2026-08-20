# Community Openness Notes

Source tutorial:

- https://www.cnblogs.com/Aifen/p/20362487

Use this as a practical community reference, not as the primary authority. Prefer Siemens official Openness documentation for API truth, and use this note to capture the implementation tactics that are worth applying locally.

## What is useful from the tutorial

- Attach to an already running TIA Portal process when interactive authorization or reuse is needed.
- Force devices offline before modifying program content, otherwise Openness may fail with online-mode restrictions.
- For SCL generation, use External Sources as the easiest text-first path.
- For LAD generation, do not hand-write a full block XML document from scratch.
- Export a valid block XML first, then modify only the `NetworkSource` / `FlgNet` content, then import and compile.
- Pre-create required PLC tags before generating LAD content to avoid unresolved symbols or `???`-style references.
- Compile inconsistent blocks before export, because inconsistent blocks may not export cleanly.
- For manual/auto merge logic in LAD, follow the exported branch pattern exactly: branch contacts first, then `O` part merge, then the final coil or timer path.
- For shared-prefix branch logic, keep the exported fanout shape exact: when one upstream compare feeds several downstream compares or contacts, preserve the single shared wire with multiple target `NameCon` nodes instead of emitting one separate wire per target.
- The same exported-wire rule applies when one upstream path feeds both a direct action and downstream branch heads; keep every same-source target on one fanout wire if the real export does.

## What we verified on this V17 machine

- The current project export format is `Engineering version="V17"`.
- V17 LAD exports here still use `NetworkSource` with `FlgNet` namespace `http://www.siemens.com/automation/Openness/SW/NetworkSource/FlgNet/v4`.
- The exported block structure already matches the tutorial's core LAD editing strategy:
  - keep the original block shell
  - replace or patch `NetworkSource`
  - re-import and compile
- A local V17 validation now confirms that a generated `O` branch with `Card=2`, `in1` / `in2`, and powerrail fanout imports and compiles on the real `手动程序` project.
- A local V17 validation now also confirms that a shared-prefix compare branch imports and compiles only when the prefix output fans out through one multi-target wire to the downstream `pre` inputs.
- A local V17 validation now also confirms that a mixed direct-action plus branch network imports and compiles only when the direct action and the branch heads share the same upstream fanout wire.

## How this maps to the local generic skill

- Existing good path for LAD:
  - export blocks through Openness
  - review or generate XML under `PLC_Code`
  - verify on a cloned project
  - compile and re-export
- Existing good path for editor integration:
  - client or editor
  - local REST bridge
  - generic wrapper
  - versioned TIA bridge
  - Openness API

## Next implementation priorities

1. Keep improving the attach-to-running-TIA path; the generic skill now exposes `prepare-write-session` on top of the warm-session REST flow.
2. Investigate whether an explicit Openness offline-switch API is available on this machine; do not fake it if the API surface does not support it directly.
3. Keep extending the reusable LAD patch path; the generic skill now exposes `patch-lad-network` for `NetworkSource` / `FlgNet` replacement while preserving the exported block shell.
4. Add a tag-bootstrap helper for LAD generation so symbol prerequisites can be created before import.
5. Keep SCL as the default "free writing" route for algorithmic logic, and keep LAD on the export-patch-import route for maintenance-facing logic.

## Guardrails

- The tutorial targets TIA Portal V18, so do not hard-code V18-only assumptions into the V17 bridge without checking local exports.
- Community examples are useful for workflow design, but API signatures and environment requirements should still be cross-checked against Siemens official sources.
