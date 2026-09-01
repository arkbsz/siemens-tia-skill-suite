# Siemens TIA Skill Suite

Version: `1.0.0`  
Release date: `2026-08-10`

面向 Siemens TIA Portal 的多平台技能套件，兼容 Codex、Claude Code 与 Cursor，主打 PLC-as-code 与 HMI/WinCC 自动化工作流。适合做项目备份、块导出、LAD/XML 编辑、WinCC 画面与标签自动化、源码导入、编译验证，以及本地 Openness / REST 桥接自动化。

## 项目简介

这套仓库把 Siemens PLC 开发里常见、重复、容易出错的流程打包成可复用技能，目标是让 PLC 编程更接近普通代码开发体验。

## 多平台支持

- Codex：使用 `skills/` 下的技能目录
- Claude Code：使用仓库根目录的 `CLAUDE.md`
- Cursor：使用仓库根目录的 `.cursorrules`

三者共用同一套 TIA / Openness / LAD / SCL 资源。

## Included Skills

- `siemens-tia-plc-dev`: generic Siemens PLC workflow wrapper
- `tia-portal-v17`: local TIA Portal V17 bridge and Openness helper surface
- `codex-tia-client`: Codex-first entrypoint for backup, export, write, import, and compile loops
- `siemens-wincc-hmi-dev`: WinCC HMI automation entrypoint for screen, tag, alarm, and runtime workflows

## 功能

- 项目备份优先，先复制再改
- 导出/导入 FC、FB、DB、LAD XML、SCL
- LAD 模板化生成与网络批量写入
- WinCC 画面、标签、报警、面板与 runtime 联动自动化
- 本地 Openness 自动化和 REST 桥接
- 编译验证与回读比对
- 可复用的工业项目示例与命名规范
- 官方文档优先、社区案例补充、结合当前项目结构的知识检索路线

## WinCC 自动开发

这个套件新增了 WinCC HMI 自动化内容，适合做：

- HMI 画面、Faceplate、报警、文本和导航结构生成
- PLC 数据块与 HMI 变量映射
- WinCC Unified 运行时读写、订阅和诊断联动
- SiVArc 规则驱动的界面生成和批量配置

## What Is Intentionally Excluded

- `Siemens.Engineering.dll`
- `Siemens.Engineering.Hmi.dll`
- `Siemens.Engineering.WinCC.dll`
- `Siemens.Engineering.WinCCUnified.dll`
- `Siemens.Engineering.Sivarc.dll`
- prebuilt `TiaPlcTool.exe`
- session caches and Python bytecode

These binaries are excluded so the package can bind to the target machine's own TIA Portal V17 PublicAPI installation and rebuild local helper binaries when needed.

## Install

1. Download or extract this repository.
2. Run `install-skills.ps1`.
3. Restart Codex if it is already open.

## 一键部署

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install-skills.ps1
```

Default install target:

- `%USERPROFILE%\.codex\skills`

## 推荐使用顺序

1. 先运行 `doctor` 检查本机 Openness 会话是否就绪
2. 就绪后再做 `list-plcs`、`export-blocks`、`verify-lad-change`
3. 如果会话未就绪，先走离线 XML / SCL / 模板化开发路线，不要反复卡在 live Openness

示例：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\siemens-tia-plc-dev\scripts\invoke-siemens-plc-dev.ps1 doctor -ProjectPath "D:\path\to\project"
```

## Target Machine Prerequisites

- TIA Portal V17
- Openness PublicAPI available under the local TIA installation
- .NET Framework 4.8 or compatible local build environment
- A Windows user configured for `Siemens TIA Openness` when write workflows are required

## Repository Layout

- `skills/`: packaged Codex skills
- `install-skills.ps1`: local installer for the skill suite
- `release-manifest.json`: packaged metadata and validation record
- `LICENSE`: MIT license for the repository

## Validation Basis

- The packaged skills were used to complete offline `backup -> source import -> block import -> compile -> LAD export/readback` loops.
- The validated ladder workflow includes timer-backed LAD changes, batch network rewrites, and support-source import for helper DB artifacts.
- The recent industrialization and simulation overlay validated `DB_7SimulationPanel`, `FC7_SimulationIO`, and `TON.PT` bound to a DB `TIME` variable.

## Knowledge Sources

- Siemens official instruction-family pages on `docs.tia.siemens.cloud`
- Siemens support manuals and Openness documents on `support.industry.siemens.com`
- Siemens official GitHub Openness snippets
- community case studies and open-source tooling
- the active project's exported LAD XML, summaries, SCL sources, and DB structures

## Notes

- Prefer working on a backup or clone before importing changes into a main project.
- Use exported XML and SCL artifacts as the reviewable source of truth whenever possible.
- Treat this repository as a distributable skill suite, not as a bundle of Siemens runtime binaries.
