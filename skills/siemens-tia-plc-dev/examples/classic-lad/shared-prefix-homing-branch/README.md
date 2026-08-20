# Shared Prefix Homing Branch

Use this example when one ladder network has:

- one shared prefix condition path
- two or more downstream compare or contact branches
- separate action paths per branch

This shape was validated on the FC2 homing step 2 network of a real S7-1200 project.

Key detail:

- the shared prefix output must fan out through one wire that targets every downstream `pre` input
- separate one-wire-per-target output links looked acceptable in XML, but TIA import rejected that shape
