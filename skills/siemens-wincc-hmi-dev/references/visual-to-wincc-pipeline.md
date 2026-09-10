# Visual To WinCC Pipeline

Use this reference when a text brief or uploaded reference image should become editable WinCC engineering content.

## Multi-Stage Workflow

1. Intake
   Read the user request, target WinCC flavor, screen size, PLC/HMI tag contract, reference image path, and plugin-routing report.

2. Reference generation or analysis
   If the user supplied only text, create a reference mockup through the configured image workflow. If the user supplied an image, analyze layout, zones, palette, typography, component density and operator scan path.

3. Component decomposition
   Split the design into header, navigation, status/alarm strip, process area, station cards, device controls, trends, parameters and maintenance panels.

4. Component selection
   Prefer existing project faceplates, then standard WinCC controls, then SiVArc repeated-object rules, then custom faceplates, then CWC only when the widget cannot be represented cleanly with native objects.

5. Contract mapping
   Bind every command, feedback, interlock, fault, parameter and diagnostic indicator to a reviewed PLC DB/UDT or HMI tag. Never let one tag act as both command and feedback.

6. Engineering generation
   Use Openness for engineering-time objects, SiVArc for rule-based repeated screens, reviewed TIA MCP adapters when compatible, and manual fallback notes when an API cannot create the target object.

7. Implementation packaging
   Run `wincc-openness-implementation` after the engineering scaffold. Generate screen/object maps, packaged HMI tag/alarm implementation inputs, a clone-only Openness runner and reference C# notes. The runner creates a clone, applies supported Unified objects, reads the clone back, and records evidence; it never writes production.

8. Validation
   Compile or smoke-test on a clone. For Unified runtime, GraphQL or runtime MCP may be used only on trusted endpoints and only for the requested read/write scope.

9. Scenario replay
   Run `simulation-replay` after `simulation-package` to turn compile, manual/automatic, interlock/fault, sequence, drive communication and WinCC runtime checks into evidence statuses. Missing PLCSIM or runtime prerequisites remain explicit next steps.

10. Release
   Package the screen map, component map, style guide, generated assets, scripts, tag changes and risk notes.

## Required Outputs

Each WinCC visual task should create:

- `design-brief.md`
- `reference-analysis.md`
- `screen-map.md`
- `component-map.md`
- `component-selection-matrix.md`
- `style-guide.md`
- `tag-contract.md`
- `implementation-plan.md`
- `plugin-invocation-plan.md`
- `cwc-faceplate-package.md`
- `engineering-tasks.json`
- `safety-review.md`
- `PLC_Code\wincc\engineering-scaffold\latest\wincc-engineering-scaffold.md`
- `PLC_Code\wincc\engineering-scaffold\latest\hmi-tag-import-map.csv`
- `PLC_Code\wincc\engineering-scaffold\latest\alarm-import-map.csv`
- `PLC_Code\wincc\engineering-scaffold\latest\clone-validation-plan.md`
- `PLC_Code\wincc\openness-implementation\latest\README.md`
- `PLC_Code\wincc\openness-implementation\latest\implementation-manifest.json`
- `PLC_Code\wincc\openness-implementation\latest\screen-object-map.csv`
- `PLC_Code\wincc\openness-implementation\latest\WinccEngineeringSkeleton.cs`
- `PLC_Code\simulation\replays\latest\replay-report.md`
- `PLC_Code\simulation\replays\latest\replay-report.json`

For task planning from the native workbench, also generate `PLC_Code\agent-plans\latest-plan.md`.

## Component Strategy

- Existing faceplate: best for project consistency and DB/UDT alignment.
- Standard control: best for buttons, lamps, I/O fields, trends, alarms and navigation.
- SiVArc rule: best for repeated stations, devices and screens generated from PLC structures.
- Custom faceplate: best for a reusable device card or station card.
- CWC: best for charts, tables or widgets that are impractical with built-in Unified controls.
- Static image: allowed only as reference or decorative background, never as the operational HMI itself.

## Automation Execution Pattern

1. Run `resolve-wincc-plugins.ps1` and read `PLC_Code\wincc\plugin-routing.json`.
2. If the user supplies text only, generate a reference mockup using the configured image workflow, then convert the mockup into editable components.
3. If the user supplies a screenshot/reference image, analyze it into zones, palette, typography, component density, object hierarchy and operator scan path.
4. Build `component-selection-matrix.md`: every visual item must resolve to an existing faceplate, standard control, SiVArc-generated repeated object, custom faceplate or CWC.
5. Run `wincc-engineering-scaffold` to turn the visual package and component blueprints into HMI tag/alarm import maps, faceplate build lists, SiVArc/CWC checklists, runtime smoke plans and clone-validation plans.
6. Run `wincc-openness-implementation` to convert the scaffold into a concrete, reviewable implementation package. Treat `WinccEngineeringSkeleton.cs` as a version- and project-specific starting point, not as a blind universal importer.
7. Build or update `engineering-tasks.json`: keep each screen, tag, alarm, faceplate, CWC asset and validation action as a separate task that can be executed or reviewed from the workbench.
8. Run `simulation-replay` after `simulation-package` when scenario evidence should be visible in the workbench.
9. Use Openness/SiVArc only on a backup or clone for first writes. Runtime GraphQL validation is read-only unless the user explicitly requests a trusted write/ack action.

## Quality Gates

- Text is readable in Chinese and English.
- Commands are visually distinct from indicators.
- Reset, homing, recipe write and force-like actions require confirmation or authority.
- Disabled commands show the reason through interlock or mode status.
- Alarm/status strip is visible from primary operation screens.
- The final HMI remains editable and maintainable in WinCC.

## Source Anchors

- Siemens SiVArc Openness generation documentation: `https://docs.tia.siemens.cloud/r/en-us/v21/sivarc-openness/sivarc-generation`
- Siemens WinCC Unified GraphQL runtime documentation: `https://docs.tia.siemens.cloud/r/en-us/v20/wincc-unified-graphql-rt-unified/introduction-rt-unified`
- Siemens WinCC Unified Custom Web Control application examples: `https://github.com/tia-portal-applications/CWC-in-WinCC-Unified`
- Siemens TIA Portal Openness code snippets: `https://github.com/siemens/tia-portal-openness-code-snippets`
- reviewed community MCP/Openness adapters only after source and license review
