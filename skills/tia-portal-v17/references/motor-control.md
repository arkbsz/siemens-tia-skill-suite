# Motor Control Patterns

## Standard Motor Control (FB)
- Inputs: StartCmd, StopCmd, FaultReset, Interlock
- Outputs: RunFeedback, Fault
- Status: Run, Fault, InterlockActive
- Logic: Set/Reset with priority, interlock, thermal protection

## VFD Motor Control
- Setpoint: SpeedSetpoint (REAL), RampTime
- Feedback: SpeedActual, Current, Torque
- Control: Enable, Start, Stop, Setpoint
- PROFIdrive telegram: Telegram 1 (speed control)

## Star-Delta Starter
- Timing: StarContact -> delay -> DeltaContact
- Status: StarRun, DeltaRun, TransitionFault

## Soft Starter
- Bypass after start complete
- Current limit monitoring
- Start/stop ramp control
