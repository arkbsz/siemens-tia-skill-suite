# WinCC Screen Design Rules

Use this reference when generating or refactoring WinCC screens, faceplates, navigation, alarms, and diagnostics.

## Screen Map

Start with a clear screen map before placing controls.

- Overview: machine state, production readiness, station summary, active alarm, current mode, and cycle/step status
- Manual: station-by-station jogging, actuator feedback, interlocks, and safe command enable conditions
- Automatic: sequence step, permissives, cycle status, holds, retries, and station progress
- Alarm: active faults, warning history, acknowledgement, reset guidance, and first-out information when available
- Trend: key analog values, cycle time, pressure, speed, temperature, and process quality indicators
- Parameter: recipe, timing, thresholds, engineering limits, and change authority
- Maintenance: I/O monitor, diagnostics, bypass records, counters, and service actions
- Diagnostics: PLC/drive/communication status, module health, network status, and raw fault words

## Layout

Make the operator's first scan useful.

- keep one stable header with machine name, current mode, PLC connection state, user level, and time
- reserve one stable footer or side strip for alarm and navigation status
- use a left-to-right or top-to-bottom process flow that matches the real machine whenever possible
- place commands near their feedback, but keep command buttons visually distinct from indicator lamps
- use station panels with consistent fields: state, command, feedback, interlock, fault, and maintenance note
- keep manual controls grouped by physical device, not by tag table order
- leave enough spacing for translated labels and longer Chinese text

## Visual Style

Prefer a clean industrial panel style over decorative dashboards.

- background: low-contrast neutral gray or blue-gray with clear content zones
- normal state: quiet neutral
- running state: green or cyan
- warning state: amber
- fault state: red
- manual or bypass state: blue or violet accent, used sparingly
- disabled state: low contrast with unchanged layout
- avoid using color as the only signal; pair color with text, icon, or state label
- keep fonts, title sizes, object widths, and alignment consistent across screens

## Controls And Safety

Operator actions should be obvious and hard to trigger accidentally.

- separate Start, Stop, Reset, Home, Manual Jog, and Parameter Write actions by intent
- require confirmation for reset, homing, recipe write, bypass, force-like, and maintenance actions
- show why a command is unavailable: missing permissive, active fault, wrong mode, guard open, or communication fault
- display feedback beside every output command so the operator can see whether the field device responded
- avoid hiding faults inside faceplates without also showing summary state on the parent screen

## Naming

Use bilingual and traceable names when the project needs Chinese operator text and English engineering names.

- screen names: `画面_Overview_Main`, `画面_Manual_Station01`, `画面_Alarm_Active`
- faceplate names: `FP_Motor_电机`, `FP_Cylinder_气缸`, `FP_Drive_变频器`
- HMI tags should mirror PLC DB structure where practical, such as `DB_Station01.ModeAuto` or `DB_1手动数据块.设备启动`
- object names should include function and station, such as `Btn_Station01_Start`, `Ind_Station01_Running`, `Txt_Station01_Alarm`

## Review Checklist

Before considering a generated HMI ready:

- every screen has a clear purpose and one primary operator task
- navigation is stable and predictable
- alarms and interlocks are visible where actions are taken
- controls and indicators are visually different
- station panels follow one shared structure
- Chinese text fits without overlap
- PLC tags, HMI tags, faceplates, and screen names can be traced back to the same equipment model
- risky commands have confirmation or authority checks
