surfaces: ios
agent: codex gpt-6-astra
task: diagnose delayed vertical motion in a send flight

### Rough
- the final landing aligned, but the flight's velocity still differed from the template. native recordings showed a plateau before the rise. source tracing and temporary geometry probes are needed to distinguish a moving target from host spring behavior; a frame-by-frame animation target diagnostic would help.

- adding a temporary native probe rebuilt the full module set, with quiet intervals of over a minute. a small diagnostics API would avoid recompiling unrelated modules just to inspect a flight target.

- measuring only final alignment missed the changing target. the receipt height transition also restarted automatic end-follow, so freezing only the new receipt left the list behind the flight. source inspection and frame traces took about thirty minutes; a recipe showing stable destination geometry and interactions with end-follow would help.

### Lean in
- the template provides explicit phases and spring parameters for comparison.
- frame geometry can express the final row suffix without changing the framework.

### Needed
- animation diagnostics: by hand, compare recorded frames and logical target coordinates.

### Checkpoints
- editing the view: rough, the initial target geometry missed the row suffix; native probes exposed it.
- building and verifying: smooth after the diagnostic rebuild; native tests and visual checks passed.
- native geometry probes confirmed repeated retargets: the rise began about 24 points below its final destination. accounting for row suffix geometry and settling receipt space reduced the late target change to under one point in short and multiline sends.
- all temporary probes were removed; the final native recordings were inspected. native verification passed: 14 tests, light/dark and 16 largest-text screens clean. the final navigation-focus correction passed the same native suite.
