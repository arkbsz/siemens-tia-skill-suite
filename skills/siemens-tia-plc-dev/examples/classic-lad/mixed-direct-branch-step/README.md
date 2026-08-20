# Mixed Direct Branch Step

Use this example when one sequence network has:

- one shared prefix condition path
- one direct output action on that prefix
- one or more downstream branch compares or contacts
- one branch that advances the step with `MOVE`

This shape was validated on the FC5 automatic sequence block of a real S7-1200 project.

Key detail:

- the direct action input and every downstream branch entry must sit on one shared source wire
- splitting them across separate wires from the same source output caused TIA import failure before the fanout fix
