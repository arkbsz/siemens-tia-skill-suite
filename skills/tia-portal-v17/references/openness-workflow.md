# Openness Workflow

This reference distills the useful parts of:

- Siemens official TIA Portal Openness code snippets
- TIA Openness plugin-style routing approaches
- project automation patterns used in community tooling

## When to prefer Openness

Use Openness when the task depends on the engineering object model:

- open or inspect a project
- traverse devices and software containers
- list PLC blocks, tag tables, UDTs, alarms, or HMI elements
- export/import engineering artifacts

## Good working style

### Start read-only

First answer these:

- Can the project be opened?
- What devices and software containers exist?
- Which PLCs and HMIs are present?
- Which blocks or tags are relevant to the request?

### Keep lifecycle explicit

Typical sequence:

1. create or attach to a TIA Portal session
2. open the project
3. locate target objects
4. inspect or export first
5. apply the smallest write
6. save or export validation artifacts
7. close cleanly

### Prefer official snippet patterns

The Siemens snippet repository is useful as a baseline for:

- object traversal
- project opening
- device and software access
- isolated example execution

When uncertain about API behavior, align with the official snippet style before inventing new patterns.

## Best uses in this skill

- planning project automation
- designing helper tools or scripts
- deciding whether a task should be implemented in C# or via an MCP bridge

## Avoid

- direct binary mutation without the engineering model
- large blind write batches before a read/export pass
- mixing GUI clicking and Openness writes unless necessary
