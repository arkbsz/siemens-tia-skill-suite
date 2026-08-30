# Batch Reset Plus TON

Source case:

- `D:\path\to\project\PLC_Code\changes\fc1-batch-reset-plus-ton\batch-manifest.json`

What it shows:

- one batch manifest that rewrites two ladder networks in one block
- one reset-fanout network and one timer-backed alarm network in the same generated artifact
- one sibling `supporting-sources` directory that provides a new `IEC_TIMER` instance DB
- a real imported and compiled batch change on `FC1_报警程序块`

Use it when one change request spans several networks and at least one of them needs a helper source artifact.
