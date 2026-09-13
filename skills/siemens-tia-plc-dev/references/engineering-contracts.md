# Engineering Contract Evidence

Use `analyze-engineering-contracts.ps1` to check the relationship between exported PLC blocks, DB members, LAD/FBD references and WinCC contracts.

## Evidence Levels

- `VERIFIED_MEMBERS`: the DB exists in the block list or XML and its member XML was indexed.
- `BLOCK_ONLY`: the DB exists in the block list but member XML was not exported.
- `XML_WITHOUT_MEMBERS`: a DB XML was found, but no member nodes were indexed.
- `MISSING_MEMBER`: the DB has member evidence, but the referenced member path is absent. This is a confirmed `FAIL`.
- `UNVERIFIED_INSTANCE`: an instruction instance is not present in the current block/XML evidence. This is a `WARN` until clone compilation or a supporting source confirms it.

Do not convert `BLOCK_ONLY`, `XML_WITHOUT_MEMBERS`, or `UNVERIFIED_INSTANCE` into a production defect without a clone compile or a fresh Openness readback.

## WinCC Binding Contract

The visible HMI tag name is an alias. A concrete PLC binding should be carried in one of these CSV columns:

- `plcPath`
- `plcTag`
- `binding`
- `plcVariable`
- `address`

The same binding may be written in a `tag-contract.md` table with a `PLC Binding` column. The analyzer records the alias, binding value, binding source, data type and resolution result in `hmi-plc-reference-index.csv`.

Recommended review order:

1. Resolve explicit HMI PLC bindings.
2. Confirm DB data type and access direction.
3. Confirm command, feedback, status and interlock signals remain separate.
4. Confirm alarm triggers, acknowledge behavior and reset semantics.
5. Compile and smoke-test the clone before any release approval.
