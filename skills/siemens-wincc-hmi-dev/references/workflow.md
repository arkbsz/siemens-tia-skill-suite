# Workflow

1. Identify the WinCC flavor: Advanced, Unified engineering, Unified runtime, or SiVArc.
2. Back up the project or work on a clone.
3. Inspect read-only artifacts first: screens, tags, alarms, faceplates, and HMI/PLC data links.
4. Use Openness for engineering-time config.
5. Use SiVArc when the task is rule-based screen or asset generation.
6. Use GraphQL for Unified runtime access; use Open Pipe when a lightweight runtime connector is enough.
7. If the required license is missing, keep the task read-only and only browse existing objects.
8. Keep PLC DB names, HMI tag names, and screen names aligned, then compile and do a minimal runtime smoke test.
