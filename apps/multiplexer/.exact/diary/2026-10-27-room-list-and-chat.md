surfaces: ios
agent: Claude Code, Claude Opus 5.5
task: a chat list (plain list, name, time, two-line preview, rows that push) and a read-only chat transcript from a native module's data

### Rough
- The room list's top row (name `flex=1 min-width=0`, then the time and a chevron) drew the time over the name at the largest text size. `verify ios` could not see it: its tests cannot sign in, so they never reach that screen. ~5 min with `xcrun simctl ui … content_size`. Fixed as `verify`'s advice says elsewhere: `flex-wrap="wrap"`, the name `flex="1 1 10rem"`, the time `flex-shrink=0`. A screen only a signed-in drive reaches gets no largest-size check; a `verify`-style `check` at the largest text size inside an `agent` drive would have caught it.

- The `chat-thread` recipe's bubble has `overflow-wrap="anywhere"`; `verify ios` then reported "breaks inside words (Octo/ber)". `break-word` made it clean. ~2 min. The recipe and `verify` disagree.

- The module keeps the signed-in session in the Keychain and the library's store in `context.data`. `verify ios` started the agent's data afresh, which emptied `context.data` but not the Keychain, and told the module nothing. The next drive opened signed out, and the module (seeing a session whose store was gone) dropped it without signing out on the server, so a test device stayed on the account. ~10 min to understand; the device must be removed by hand. What would have helped: the agent's fresh storage also clearing a Keychain service the module names (or `context` saying the storage was reset), so a module's secrets live and die with its data.

- An authored test cannot sign in: the password must not be in `app.test.contract`, and a test has no way to read one from the environment or the Keychain. So `verify ios` never reaches the screens behind sign-in, and those were checked by drives that type the password from a shell variable. What would have helped: a test step that reads a named secret from the environment (`type "password" env "TEST_PASSWORD"`), masked in every report.

- Under the agent the clock is 2026-01-01, so `formatDay(…, "list")` of today's messages showed `10/27/26`. `--epoch now` fixed it; I found the flag in `agent --help all`. ~2 min.

### Lean in
- A `list` with no `appearance` gave Messages' plain list (separators, the pressed grey, rows that push) with no code.
- `formatDay(then, shown, offset, "list")` is exactly a chat list's time; `"day-time"` gave "Today at 2:18 PM" headers.
- `tree --ax` gave frames in points, which settled a centring doubt that a screenshot could not.
- The `chat-thread` transcript (`scroll-start="end"`) opened a 20-message chat at the newest with no code.

### Needed
- none

### Checkpoints
- editing app.contract / app.ts: smooth
- iOS build: smooth
- driving the app (`exact.mjs agent`): smooth (`--epoch now`)
- `verify ios`: rough (cannot reach signed-in screens; see Rough), then clean
