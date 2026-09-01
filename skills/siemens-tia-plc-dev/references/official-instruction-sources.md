# Official Instruction Sources

Use these official documents first when expanding instruction coverage.

## Core manuals

- S7-1200/S7-1500 Standard Instructions manual:
  `https://support.industry.siemens.com/cs/document/1214574`
- Programming Guideline for S7-1200/S7-1500:
  `https://support.industry.siemens.com/cs/document/81318674`
- TIA Portal Openness overview:
  `https://support.industry.siemens.com/cs/document/109792902`
- TIA Portal Openness getting started and demo application:
  `https://support.industry.siemens.com/cs/document/108716692`
- Siemens official Openness code snippets:
  `https://github.com/siemens/tia-portal-openness-code-snippets`

## Instruction family pages

- Bit logic operations:
  `https://docs.tia.siemens.cloud/r/en-us/v20/stl-s7-scl/bit-logic-operations-s7-1200-s7-1500`
- Timer operations:
  `https://docs.tia.siemens.cloud/r/en-us/v20/stl-s7-scl/bit-logic-operations-s7-1200-s7-1500/timer-operations-iec-timers-s7-1200-s7-1500`
- Counter operations:
  `https://docs.tia.siemens.cloud/r/en-us/v20/stl-s7-scl/bit-logic-operations-s7-1200-s7-1500/counter-instructions-iec-counters-s7-1200-s7-1500`
- Comparator instructions:
  `https://docs.tia.siemens.cloud/r/en-us/v20/stl-s7-scl/comparator-instructions-s7-1200-s7-1500`
- Move instructions:
  `https://docs.tia.siemens.cloud/r/en-us/v20/stl-s7-scl/move-instructions-s7-1200-s7-1500`
- Arithmetic instructions:
  `https://docs.tia.siemens.cloud/r/en-us/v20/stl-s7-scl/add-subtract-multiply-and-divide-instructions-s7-1200-s7-1500`
- Math functions:
  `https://docs.tia.siemens.cloud/r/en-us/v20/stl-s7-scl/math-functions-s7-1200-s7-1500`
- Conversion operations:
  `https://docs.tia.siemens.cloud/r/en-us/v20/stl-s7-scl/conversion-operations-s7-1200-s7-1500`
- Word logic operations:
  `https://docs.tia.siemens.cloud/r/en-us/v20/stl-s7-scl/word-logic-operations-s7-1200-s7-1500`
- Shift and rotate operations:
  `https://docs.tia.siemens.cloud/r/en-us/v20/stl-s7-scl/shift-and-rotate-instructions-s7-1200-s7-1500`
- String operations:
  `https://docs.tia.siemens.cloud/r/en-us/v20/stl-s7-scl/string-operations-s7-1200-s7-1500`

## Reading rule

- Use the standard instruction manual to understand the instruction family and expected semantics.
- Use Openness docs and official code snippets to understand how to automate import, export, compile, and object traversal.
- Use exported block XML from the target project to confirm the exact ladder `FlgNet` shape before adding a new direct JSON writer path.
- When an instruction family is mostly numeric, conversion-heavy, string-heavy, or word-packed, prefer validating the authoring route in SCL first and then decide whether a ladder surface is still needed.
