# Workflow

1. Identify the WinCC flavor: Advanced, Unified engineering, Unified runtime, or SiVArc.
2. Back up the project or work on a clone.
3. Inspect read-only artifacts first: screens, tags, alarms, faceplates, and HMI/PLC data links.
4. Draft or update the screen map before creating objects: Overview, Manual, Automatic, Alarm, Trend, Parameter, Maintenance, and Diagnostics.
5. Use Openness for engineering-time config.
6. Use SiVArc when the task is rule-based screen or asset generation.
7. Use GraphQL for Unified runtime access; use Open Pipe when a lightweight runtime connector is enough.
8. If the required license is missing, keep the task read-only and only browse existing objects.
9. Keep PLC DB names, HMI tag names, and screen names aligned, then compile and do a minimal runtime smoke test.
10. Review layout quality with `references/screen-design.md` before calling the HMI package done.
