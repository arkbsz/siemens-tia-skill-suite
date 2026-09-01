# Machine Notes

These notes are specific to the current workstation profile this skill was designed for.

## Expected local paths

- `V17-V20` main install: `C:\Program Files\Siemens\Automation\Portal VXX`
- `V17-V20` public API: `...\PublicAPI\VXX`
- `V21` public API: `...\PublicAPI\V21\net48`
- main assembly:
  - `V17-V20`: `Siemens.Engineering.dll`
  - `V21`: `Siemens.Engineering.Base.dll`

## Practical implications

- A `.ap17` through `.ap21` project may be opened by TIA but not be directly editable as plain text.
- If `Siemens.Automation.Portal` is running, backup may fall back to snapshot mode because project files are locked.
- If the user is not in the `Siemens TIA Openness` Windows group, Openness open/attach/read/write scenarios may fail even when the DLLs exist.
- If the user was added to the `Siemens TIA Openness` group after logging in, a new PowerShell window is usually not enough; a full Windows sign-out and sign-in is typically required before the current logon token contains the group.
- The project directory often contains useful metadata:
  - `System\PEData.*`
  - `XRef\XRef.db`
  - `Vci\Vci.db`
  - root `.ap17` through `.ap21`

## Read-first strategy

For local binary TIA projects:

1. inspect project directory layout
2. capture backup
3. identify whether exported source exists
4. use Openness or MCP when deeper project introspection is needed

## Minimum prerequisites for Openness-style work

- TIA Portal V17, V18, V19, V20, or V21 installed
- .NET Framework 4.8 available
- access to the version-matching Openness assemblies
- current Windows user configured in `Siemens TIA Openness`
- current Windows logon token already contains `Siemens TIA Openness`

Run the bundled probe script instead of assuming these are all satisfied.
