# Built-in Agent console

`PLCDevConsole.exe` uses the installed Codex CLI as its local Agent runtime. It does not embed an API key or start a second browser window.

## Interaction model

- A new conversation runs `codex exec --json` in the selected project root.
- Later messages run `codex exec resume --json <thread-id>` so project context and conversation history continue.
- JSONL events are split between the AI conversation view and the technical log view.
- Uploaded files are copied into `PLC_Code\agent-attachments` before execution so the Agent can read them from the project workspace.
- Images are also passed through the Codex CLI image attachment option.
- Every request, attachment manifest, JSONL stream, and stderr log is retained under `PLC_Code\agent-sessions`.

## Built-in profiles

Profiles are stored in `agents/siemens-agent-profiles.json`:

- automatic router
- PLC LAD engineer
- PLC SCL engineer
- DB and tag architect
- WinCC screen engineer
- Openness automation engineer
- compile diagnostics agent
- read-only reviewer

The profile supplies role guidance and required skills. The UI model, search, and sandbox controls remain the effective runtime settings.

## Safety

Use `read-only` for reviews, `workspace-write` for normal PLC-as-code work, and reserve `danger-full-access` for an explicitly reviewed operation. Agent integration does not change the production-write guardrail: PLC and HMI edits should still use backup/clone-first verification and require explicit confirmation before the production project is changed.

## CLI route

The same adapter can be used without the UI:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1" agent-chat -ProjectPath "D:\path\to\project" -PromptFile "D:\path\to\message.txt" -AgentId plc-lad -Sandbox workspace-write -Search
```

Do not place API keys in `ai-workflow.json`. Codex CLI authentication and provider configuration remain in the user's normal Codex configuration.
