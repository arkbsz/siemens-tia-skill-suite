# Siemens TIA Skill Suite

这个仓库也可直接给 Claude Code 使用。

## 先读这些

- `README.md`
- `skills/siemens-tia-plc-dev/SKILL.md`
- `skills/tia-portal-v17/SKILL.md`
- `skills/siemens-tia-plc-dev/references/knowledge-retrieval.md`
- `skills/siemens-tia-plc-dev/references/instruction-routing.md`

## 工作原则

- 先备份，再改项目。
- live Openness 前先跑 `doctor`；如果 `ReadyForOpennessSession = false`，就先走离线 XML / SCL。
- LAD 优先用于维护面逻辑，算法、转换、字符串、位打包优先用 SCL。
- 查资料优先官方文档，其次社区案例，再结合当前项目导出。
- 命名尽量清晰，保持中文/英文双语风格一致。
- 不要反复卡在一个会话上，必要时切换到离线路线。
- 不要修改 TIA 二进制存储。
