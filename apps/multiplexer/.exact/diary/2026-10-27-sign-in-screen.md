surfaces: ios
agent: Claude Code, Claude Opus 5.5
task: a sign-in screen whose work is a slow native call (network, seconds): a grouped form, a progress state, an alert that names the failure, a session kept across launches

### Rough
- Put a `progress` in a `role="status"` readout in the header, in place of the Sign In bar button while the sign-in ran (UIKit's habit: an activity indicator replaces the bar item). `contract build` passed with no warning; on iOS the bar showed nothing. Only `tree` said why: `[not in the iOS bar: hidden in the app]`. ~5 min. Moved the spinner to its own section under the fields. A compile warning (as `lower-header-unplaced` does for other header content) would have caught it before the build.

- `prefer root-font-size 53` scaled the Contract's text but not the native fields or the grouped list's footer, so the screenshot looked broken at the largest size. `verify ios` had said "nothing spills". ~3 min. `xcrun simctl ui <udid> content_size accessibility-extra-extra-extra-large` showed the real screen, which was correct. A note on `prefer root-font-size` that native controls keep the system size (or a `prefer` key that sets the content size category) would have helped.

- `reload` in an interactive `agent ios` drive refused ("supports web"). Each drive is a new launch, so a second drive proved the relaunch. ~1 min.

- `verify ios` reported 13 findings (covered, contrast, overlap) on a test that ended with an alert open. True to the rule (a test's end is a screen it checks), but the findings did not say an alert was up. ~2 min.

- The app's data comes only from the iOS module, so on the web every sign-in test fails. There is no way to say "this app (or this test) is iOS only": `update --without` takes linux and android, not web, and a test has no host line. Workaround in the app's AGENTS.md: "run `test ios` and `verify ios` only". ~3 min to look. What would have helped: `--without web`, or a `host ios` line on a test.

- A drive that signs in types the password from the Keychain; `tree` and the `type` reply mask it (good). But `state` prints the `state password` slot that the field is bound to, in clear. Workaround in AGENTS.md: "do not run `state` before the sign-in ends". ~2 min. What would have helped: `state` masking a slot that a `type="password"` field binds, as `tree` masks the field.

- Learning the module API took reading `host/apple/modules/ExactNativeModule.swift` (77 KB) and `build.mjs`: the native-module recipe does not say that `context.data` is the app's data folder (a scratch tree under the agent), which Swift language mode modules compile in (`-swift-version 5`, so a `Task { @MainActor in … }` inside `later` is fine), or that `clock data` waits for a `native.later` reply (it did, for a reply that took seconds). That last one needed a grep of three long guides. ~10 min in all. What would have helped: three lines in `recipes/native-module.md`.

- `contract vocab input` printed only "input: tag, TextInput (html)" and `contract vocab listStyle` only "prop listStyle, str", so the attributes (`autocomplete`, `autocapitalize`, `enterkeyhint`) and the list styles came from `card.md` and a table in `contract-for-agents.md`. ~5 min. What would have helped: vocab printing a tag's attributes and a property's values, as the card does.

- The editor (SourceKit) marks every line of `modules/apple/*.swift` as an error ("Cannot find type 'ExactModule' in scope"), because it does not know these files compile into one module with Exact's `ExactNativeModule.swift`. Real errors show only at the next build, 31 s later. Cost: noise on every edit, and no quick feedback. What would have helped: `exact new`/`update` writing a `buildServer.json` (or a stub `Package.swift`) so the editor resolves the module.

- `"screenshot .exact/x.png --scale 3"` failed with "screenshot: unknown form 3": `--scale` is a drive flag, not a screenshot argument. ~1 min. The message could name the flag.

### Lean in
- `clock data` waited for a native `later` reply that took seconds (a real sign-in to a public server, then the first sync), so the tests and drives needed no waits.
- A password field's value is masked in every agent reply, so a real sign-in could be driven with the password from the Keychain without it reaching a log.
- `context.agent` and a scratch `context.data` under the agent kept the agent's signed-in session apart from the app's.
- The error-alert, grouped-form and fetch-loading-error recipes gave the whole screen's shape. The compiler's `lower-grouped-list` and `lower-empty-state-in-list` errors said exactly what to change.
- The `width="6.5rem"` label column scaled with Dynamic Type, and at the largest size the rows stacked the label above the field by themselves.

### Needed
- secure storage (Keychain): by hand (~15 min; the Security framework in the native module; no entitlement needed on the simulator). Exact has `secret.keep` for the data module (`recipes/files-and-grants.md`), found only later; a native module cannot reach it, and the session is used in Swift.
- sign-in: by hand (the third-party library's password login, through the native module)

### Checkpoints
- editing app.contract / app.ts: smooth (compiler messages named the fix)
- editing modules/apple Swift: rough (editor errors on every line, 31 to 36 s to a real error; see Rough)
- iOS build: rough (36 s for each Swift edit; see the first entry's Rough)
- driving the app (`exact.mjs agent`, `exact.mjs test`): rough (the hidden progress, `prefer root-font-size`, `state` shows the password, web-only failures; see Rough), then smooth
- `verify ios`: smooth after the test closed its alert (clean in 44 s)
