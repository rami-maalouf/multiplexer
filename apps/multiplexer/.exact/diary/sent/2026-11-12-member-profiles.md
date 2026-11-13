surfaces: ios
agent: codex
task: restore sender profile navigation and data

### Rough
- a small native module edit rebuilt all vendor bindings; about two minutes before the focused test completed. waited for the build. incremental module compilation would help (finding 1).
- after test ios, a previously signed-in drive opened signed out with no warning; about one minute to sign in again. a separate test session or explicit warning would help (finding 132).

- a signed-out route test passed assertions but verify correctly rejected its native resource refusals. retained the signed-in drive as the regression instrument instead; authenticated fixture support would allow authored coverage (about ten minutes).

- wrapping a long identifier: anywhere was rejected by the fixed-type check, while max-width alone still clipped. used break-word to split only overlong tokens. source inspection was needed to distinguish the checker's rule (about five minutes); identifier-wrapping guidance would help.

### Lean in
- avatar buttons already shared a platform-independent navigation action.

### Needed
- navigation: provided

### Checkpoints
- iOS build: smooth
- driving the app: rough, test ios cleared the kept session
- native platform taps: smooth; profile opened and Close returned to the composer

- accessibility: smooth after wrapping the overlong identifier; native light/dark checks pass at the largest text size
- final verify ios: smooth, 14 tests and visual checks clean
