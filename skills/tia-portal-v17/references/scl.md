# SCL Language Reference

## Operators
- Arithmetic: +, -, *, /, MOD, **
- Comparison: =, <>, <, >, <=, >=
- Bitwise: AND, OR, XOR, NOT
- Logic: AND, OR, NOT (BOOL)

## Built-in Functions
- Time: T#5s, T#100ms, TIME_TO_INT()
- Conversion: INT_TO_REAL(), WORD_TO_INT(), etc.
- Math: ABS, SQRT, SQR, LN, EXP, SIN, COS, TAN, ASIN, ACOS, ATAN
- Triggers: R_TRIG, F_TRIG (rising/falling edge)
- Counters: CTU, CTD, CTUD (IEC)
- Timers: TP, TON, TOF, TONR (IEC)
- Sel/Mux: SEL(G,IN0,IN1), MUX(K,IN0,...INx)
- Move: MOVE, BLKMOV, FILL

## Data Block Access
- Global DB: "DB_Name".TagName
- Instance DB: TagName (within the FB)
- Multi-instance: InstanceName.TagName

## SCL vs LAD/FBD Mapping
- AND -> AND instruction
- SR flip-flop -> SR (Set/Reset)
- MOVE -> MOVE/Assign
- Comparator -> CMP

## Best Practices
- Use meaningful prefixes: g_ (global), i_ (input), o_ (output)
- Organize with regions: REGION name / END_REGION
- One statement per line
- Document tricky logic with comments
- Use UDTs for structured data
