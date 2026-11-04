# appearance preferences

surfaces: ios
agent: codex, gpt-6.1-sol
task: add a local appearance preference and native color picker

## Rough
- theme lookup: the docs say the accent's ink is the ink on that accent, but on iOS it always resolves to white. checking arbitrary pale colors required reading the role table in framework source (~10 min). keeping an exact fill plus a calculated foreground needs explicit props because runtime custom properties are not supported. a runtime theme palette with contrast-aware ink would help.
- custom color picker: no documented color input or picker. searched docs and source, then used an app native view around the platform color picker (~10 min discovery). a native color-input recipe would remove this work.
- build location: relative framework and package paths require a private build mirror beside the usual checkout. existing finding 106 covers this; no framework or root checkout edits.

- authored test reload: a settings test relaunched on the home route despite starting with at /settings; the next reset tap found no view (~3 min). known finding 75; separated persisted-state verification from reset interaction. a reload that restores the launch route, or a documented navigation step, would help.

- dynamic navigation tint: root accent-color updates fields and in-content buttons, but a prominent native bar button stays blue after a reactive palette arrives. source inspection found AppAccent.restyled only accepts roots still parented directly by the presenter (~15 min). the suspected cause is that navigation reparents that root into a route controller. recorded display screenshots and exact palette values; the framework owner is investigating separately. full verify reports clean despite this visible mismatch. no app window-tint bridge was added.

## Lean in
- persisted root settings restore before the first frame with no file or native storage code.
- root accent-color is documented to reach platform bars, sheets and alerts.

## Needed
- color picker: by hand (native platform controller)
- local preferences: provided
- appearance: provided, rough (see Rough)

## Checkpoints
- editing app.contract / app.ts: rough (theme foreground and navigation tint, above)
- iOS build: smooth after the required private build mirror; native module compilation costs about 3 min
- driving the app: rough (reload route, above); screenshots exposed a stretched badge and duplicate picker title, both corrected
- properties: smooth; native verify passed 12 tests and checked 14 largest-text screens without a finding
