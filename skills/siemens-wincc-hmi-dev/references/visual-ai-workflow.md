# WinCC Visual AI Workflow

Use this reference when the user wants to create or refactor WinCC screens from a text description, uploaded reference image, sketch, screenshot, or style sample.

## Routing

Route by task type instead of using one model for everything:

- PLC/LAD/SCL logic, DB contracts, Openness scripts, and compile errors: use a code-capable model such as `gpt-5-codex`.
- WinCC screen architecture, PLC/HMI tag contracts, alarms, faceplates, and SiVArc rules: use a strong reasoning/code model such as `gpt-5` or `gpt-5-codex`.
- New visual concepts from text: use text-to-image workflow.
- Matching a screenshot, panel photo, or style reference: use image-to-image/reference workflow.
- Final WinCC implementation: convert the visual result into WinCC-native screens, tags, faceplates, alarms, navigation, and style rules; do not import a static image as the only HMI.
- Before generating the design, read `PLC_Code\wincc\plugin-routing.json`; explicitly call `$imagegen` when its visual-concept stage is ready, then use the selected engineering adapter for native implementation.

## Reference Image Intake

When a reference image is provided:

1. Treat it as visual guidance for layout, color, hierarchy, spacing, and component density.
2. Identify screen zones: header, navigation, alarm strip, process area, station cards, manual controls, trends, and parameter panels.
3. Extract the design system: background, card style, state colors, typography, button hierarchy, indicator shapes, and icon language.
4. Map every visible object to either a standard WinCC component, reusable faceplate, SiVArc-generated object, or custom component.
5. Preserve operator safety: command confirmation, disabled reasons, alarm visibility, authority level, and PLC connection state.
6. Generate a design note that explains which PLC DB/UDT/HMI tag contract drives each section.

## Component Selection

Prefer this order unless the user asks for a fully custom UI:

- Existing project faceplates that already match PLC DB/UDT contracts.
- Standard WinCC controls for buttons, I/O fields, trends, alarm views, navigation, and status lamps.
- SiVArc rules when screens can be generated from repeated station or device structures.
- Custom faceplates when a reference image needs a consistent reusable device card.
- Custom drawing/assets only for decoration, icons, or layout polish, not for critical control behavior.

## Output Package

For each WinCC visual task, produce a small package under `PLC_Code\ai-prompts` or the task working folder:

- `design-brief.md`: user request, model/API settings, reference image path, and screen goals.
- `screen-map.md`: screens, navigation, alarm/status strip, and station grouping.
- `component-map.md`: each component, object name, tag binding, faceplate choice, and safety note.
- `style-guide.md`: palette, fonts, spacing, state colors, and button/indicator rules.
- `implementation-plan.md`: Openness/SiVArc/manual fallback steps and verification checklist.

## Review Checklist

- The result matches the reference image's structure and feel without becoming a static screenshot.
- Every command has nearby feedback and disabled/interlock explanation.
- The main alarm/status signal is visible from primary operating screens.
- Tags and faceplates can be traced back to PLC DB/UDT contracts.
- Chinese and English labels are readable and do not overlap.
- Generated screens can be reproduced from documented settings and component mappings.
