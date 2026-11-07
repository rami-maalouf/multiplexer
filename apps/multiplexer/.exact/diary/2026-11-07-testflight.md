surfaces: ios
agent: Claude Opus 5.5
task: build a chat app's signed iOS archive for TestFlight (internal testers)

### Rough
- The archive check refuses `registerForRemoteNotifications` in any binary (LLP 1126.001 WP9), also in an app with no activity. The app's own module calls it in development builds, for push work before the push profiles exist. Packages get `-D EXACT_DEVELOPMENT` in a development build, but the app's own `modules/apple/` Swift got no flag at all, so the app had no way to keep the call out of an archive. The earlier session replaced the call in an uncommitted copy. Here: a one-line framework change (the app module's compile takes the same flag as packages) and `#if !EXACT_DEVELOPMENT` in the app. About 15 minutes to read `host/apple/activities.mjs` and `build.mjs` and find that only packages have the flag. What would have helped: the same flag for app modules from the start, and the refusal message naming the way out ("wrap a development-only call in `#if EXACT_DEVELOPMENT`").

- Pointing the build at my own framework worktree needed five app files rewritten and then `EXACT2=<checkout>` as well: the first build stopped at once with "[patch.crates-io] must name exact2's vendored ..." and printed the old paths, because `exact.mjs` still named the shared checkout. The message does not say that `EXACT2` decides which checkout it compares against. About 2 minutes. Evidence for the known finding on building against another framework checkout.

### Lean in
- The archive's failure named the rule (LLP 1126.001 WP9) and the binary, so the cause was one grep away in `host/apple/activities.mjs`.

### Needed
- One switch that points an app at another framework checkout: the launcher, the Cargo patches, the schema path and the package paths together.

### Checkpoints
- With the flag and the app's `#if`: `ios --device --archive <out.ipa> --unsigned` passed (cargo 169 s, swift 64 s, arms 70 s, package 6 s), 40.7 MB. No binary in the archive holds the refused name. No uncommitted copy was needed.
