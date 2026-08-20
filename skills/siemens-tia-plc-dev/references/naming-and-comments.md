# Naming And Comments

Use this when you want PLC code to read more like ordinary software.

## Naming rules

- Use short, plain English names that describe the role of the signal.
- Prefer `Commands`, `Inputs`, `Faults`, and `State` for grouped UDT members.
- Use `...Cmd` for commands, `...Fault` for fault sources, and `...Active` for latched alarm state.
- Keep `DB_` only for block names, not for every local variable.
- Choose names that a maintenance engineer can understand without the model context.

## Comment rules

- Comment intent, not syntax.
- Add one comment before each major logic section.
- Use comments for cause-and-effect boundaries, alarm grouping, and sequence transitions.
- Keep comments short enough to survive future edits.

## LAD style

- Prefer readable network titles.
- Use one visible behavior per network when possible.
- Keep output names aligned with the actual machine action, such as `MotorRunCmd` or `AlarmAck`.
- If a ladder network becomes algorithmic, move the algorithm into SCL and keep LAD for the operator-facing structure.
