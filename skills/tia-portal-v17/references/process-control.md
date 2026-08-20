# Process Control Patterns

## PID Control (PID_Compact)
- Mode: Pre (manual), Run (auto)
- Input: Process value (REAL)
- Output: Manipulated value (REAL)
- Parameters: Gain, Ti, Td, DeadBand
- Integrator: Anti-windup via output limits
- Typical OB: OB 30/35 (100ms/200ms cyclic)

## Valve Control
- On/Off valve: OpenCmd, CloseCmd, PositionFeedback, LimitSwitches
- Modulating valve: Setpoint (0-100%), ActualPosition
- Split-range: One output drives two valves (0-50% = A, 50-100% = B)

## Sequential Control (SFC-like)
- Step enable -> Action -> Transition -> Next step
- Steps: Init, Idle, Process_1...n, Complete, Abort
- Implement via CASE state machine or S7-GRAPH

## Alarm Management
- Process alarms: High/Low limits, Rate-of-change
- Diagnostic alarms: Device faults, communication errors
- Alarm priority: 1 (highest) to 16 (lowest)
- Ack required for critical alarms
