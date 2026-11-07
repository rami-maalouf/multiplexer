surfaces: ios
agent: Claude Opus 5.5
task: build a chat app's signed iOS archive for TestFlight (internal testers)

### Rough
- The archive check refuses `registerForRemoteNotifications` in any binary (LLP 1126.001 WP9), also in an app with no activity. The app's own module calls it in development builds, for push work before the push profiles exist. Packages get `-D EXACT_DEVELOPMENT` in a development build, but the app's own `modules/apple/` Swift got no flag at all, so the app had no way to keep the call out of an archive. The earlier session replaced the call in an uncommitted copy. Here: a one-line framework change (the app module's compile takes the same flag as packages) and `#if !EXACT_DEVELOPMENT` in the app. About 15 minutes to read `host/apple/activities.mjs` and `build.mjs` and find that only packages have the flag. What would have helped: the same flag for app modules from the start, and the refusal message naming the way out ("wrap a development-only call in `#if EXACT_DEVELOPMENT`").

- Pointing the build at my own framework worktree needed five app files rewritten and then `EXACT2=<checkout>` as well: the first build stopped at once with "[patch.crates-io] must name exact2's vendored ..." and printed the old paths, because `exact.mjs` still named the shared checkout. The message does not say that `EXACT2` decides which checkout it compares against. About 2 minutes. Evidence for the known finding on building against another framework checkout.

- A signed archive (`--archive` with `EXACT_IDENTITY` and `EXACT_PROFILE`) needs a distribution identity and an App Store profile installed on this Mac. A team that signs with Xcode's cloud-managed distribution certificate has neither, so Exact's own signed path could not be used. Workaround: the `--unsigned` archive, wrapped in a hand-made `.xcarchive`, then `xcodebuild -exportArchive -allowProvisioningUpdates` (method `app-store-connect`) signs and uploads. The first export failed: "Provisioning profile ... doesn't match the entitlements file's value for the application-identifier entitlement", because the unsigned archive's ad hoc signature carries the bare bundle id, not `<team>.<bundle id>`. Re-signing ad hoc with the team-prefixed entitlement fixed it. About 10 minutes. What would have helped: an `--archive` mode that hands the bundle to Xcode's export (cloud signing), or an `.xcarchive` output; and the unsigned archive writing the team-prefixed application-identifier when the team is known.

### Lean in
- The archive's failure named the rule (LLP 1126.001 WP9) and the binary, so the cause was one grep away in `host/apple/activities.mjs`.

### Needed
- One switch that points an app at another framework checkout: the launcher, the Cargo patches, the schema path and the package paths together.

### Checkpoints
- With the flag and the app's `#if`: `ios --device --archive <out.ipa> --unsigned` passed (cargo 169 s, swift 64 s, arms 70 s, package 6 s), 40.7 MB. No binary in the archive holds the refused name. No uncommitted copy was needed.
- The development Simulator build of the same source keeps the call (2 hits in the module library); the archive's module library has the module's other strings and 0 hits. A plain `grep` on the binaries gave 0 for both: it needs `LC_ALL=C`.
- Rough, minor: `ios` (no `--run`) installed the build on the only booted Simulator, which another conversation owned, with no notice before it did. Evidence for the known simulator-choice findings.
- `scripts/testflight.sh 1 --export` (build, wrap, re-sign, Xcode export) passed: a cloud-managed Apple Distribution signature and the team's App Store profile. The upload waits only for the app record.
