# WinCC PLC Binding Assistant

Use this workflow when a WinCC screen, tag or alarm has a human-readable alias but its PLC path is not yet known.

## Read-only candidate generation

Run the engineering contract analysis first:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" `
  engineering-contracts -ProjectPath "D:\path\to\project"
```

Generate a review package:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" `
  wincc-binding-assistant -ProjectPath "D:\path\to\project"
```

The output is written to `PLC_Code\wincc\binding-review\latest`:

- `binding-candidates.csv`: up to five candidates per HMI tag or alarm, including datatype, access and compatibility status
- `binding-review.csv`: one editable review row per HMI tag or alarm, including requested type/permission and the recommended candidate contract
- `binding-review.md`: engineer-readable review table
- `binding-assistant.json`: machine-readable run record

Candidates are based on exported DB member evidence and exported LAD global symbols. Semantic scoring is only a prioritization aid; it is not a binding approval. A candidate marked `INCOMPATIBLE` cannot be recommended. An unresolved or ambiguous result must remain unresolved until an engineer confirms the actual signal.

The compatibility pass checks:

- HMI requested datatype versus the exported PLC datatype; exact matches are preferred, numeric conversions remain review-required, and incompatible types are blocked.
- HMI `read`, `write` or `readwrite` direction versus the candidate's exported writable evidence.
- Alarm trigger datatype; when no datatype is declared, an alarm defaults to `Bool`.

## Apply an approved review

Edit `binding-review.csv`:

- set `selectedBinding` to the full path, such as `DB_2步进数据块.点动速度`
- set `decision` to `approve` or `approved`
- keep a short reason in `reviewNote`

The apply step re-resolves the selected path from the current exported evidence and rejects a path that is not a candidate, has an incompatible datatype, or is confirmed non-writable for a write request. Candidates with incomplete type or permission evidence may still be applied only after explicit human approval, and remain marked as review-required in the generated report.

Create derived maps without changing the source package:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" `
  wincc-binding-assistant -ProjectPath "D:\path\to\project" `
  -ApplyReviewPath "D:\path\to\project\PLC_Code\wincc\binding-review\latest\binding-review.csv"
```

Use `-ApplyToPackage` only after checking the derived maps and accepting the automatic backup under `PLC_Code\file-backups`. Re-run `engineering-contracts` against the applied package, then use the normal clone compile and WinCC readback gates.

The implementation intentionally ignores a CSV `source` field. `source` identifies where a row came from; it is not a PLC address.
