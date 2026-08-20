# Analog I/O Processing

## Scaling Formula
- INT to REAL scaled value:
  Scaled = ((Raw - RawLo) * (EngHi - EngLo)) / (RawHi - RawLo) + EngLo
- Siemens norm/scale blocks: NORM_X, SCALE_X

## Typical Configuration
- Analog input: 0-10V = 0-27648 (INT)
- Analog output: 4-20mA = 0-27648 (INT)
- PT100: Temperature directly scaled

## Filtering
- Moving average: Keep last N samples, average
- First-order low-pass: y = a * x + (1-a) * y_prev
- Median filter: Sort 3/5 samples, pick middle

## Error Detection
- Underflow/overflow: Check for 16#7FFF, 16#8000
- Wire break: Signal below 4mA or specific error value
- Use quality flags from analog modules (per-channel status)
