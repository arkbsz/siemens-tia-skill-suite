# Machine Notes

These notes are specific to the current workstation profile this skill was designed for.

## Expected local paths

- TIA main install: `C:\Program Files\Siemens\Automation\Portal V17`
- Openness public API: `C:\Program Files\Siemens\Automation\Portal V17\PublicAPI\V17`
- main assembly: `C:\Program Files\Siemens\Automation\Portal V17\PublicAPI\V17\Siemens.Engineering.dll`

## Practical implications

- A `.ap17` project may be opened by TIA but not be directly editable as plain text.
- If `Siemens.Automation.Portal` is running, backup may fall back to snapshot mode because project files are locked.
- If the user is not in the `Siemens TIA Openness` Windows group, some Openness attach/write scenarios may fail even when the DLLs exist.
- The project directory often contains useful metadata:
  - `System\PEData.*`
  - `XRef\XRef.db`
  - `Vci\Vci.db`
  - root `.ap17`

## Read-first strategy

For local binary TIA projects:

1. inspect project directory layout
2. capture backup
3. identify whether exported source exists
4. use Openness or MCP when deeper project introspection is needed

## Minimum prerequisites for Openness-style work

- TIA Portal V17 installed
- .NET Framework 4.8 available
- access to `Siemens.Engineering.dll`
- current Windows user ideally in `Siemens TIA Openness` group for full scenarios

Run the bundled probe script instead of assuming these are all satisfied.
