# AI workflow configuration

The native console keeps one project-level configuration file at:

```text
PLC_Code\config\ai-workflow.json
```

The quick row in the AI interaction area edits the code model, workflow, language preference, TIA session mode, safety mode, and step timeout. Advanced settings under the Tools menu write API routing, image generation, WinCC component, reference-image, and UI font values to the same file. Store only the API key environment-variable name; never store the secret value.

## Runtime mapping

- `tia.sessionMode = 显示TIA界面` makes `read-cycle` use `-UseUi`; the other session modes use `-Attach` for the console workflow.
- `tia.plcName` supplies the PLC target when a workflow does not override it explicitly.
- `tia.stepTimeoutSeconds` controls the write-cycle child-step timeout unless the caller passes an explicit timeout.
- `routing.languagePreference` controls read-cycle export order: LAD, FBD, or SCL first.
- `safety.safetyMode = 只生成不写入` blocks `write-cycle`.
- `safety.safetyMode = 克隆编译验证` verifies on a clone and forces `-SkipRelease`.
- `safety.safetyMode = 克隆验证并生成发布包` allows release packaging only after clone compile succeeds.
- `safety.allowProductionWrite` remains `false`; applying a release to the production project is a separate reviewed action.

Both `read-cycle` and `write-cycle` accept `-WorkflowConfigPath`. Each run records the source path and writes a configuration snapshot beside its `workflow-report.json`, so the effective routing and safety settings remain auditable after later configuration changes.
