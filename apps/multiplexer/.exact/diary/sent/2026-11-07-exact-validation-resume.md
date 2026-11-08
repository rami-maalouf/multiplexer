surfaces: ios
agent: codex gpt-6.1-sol
task: resume native framework validation for a chat app

# exact validation resumption

## Rough

- resuming a native test from the saved xctestrun failed with `there are no test bundles available to test`. the build runner rewrites that file for separate test groups, so its final saved form cannot replay the preceding group. cost: about 2 minutes. reran the documented `build.mjs --test --ios --only AddressedTapIOSTests` instead. a persistent per-group replay command would help.
- the affected-suite lookup failed with `TypeError: null is not an object (evaluating 'r.stderr.trim')` when cargo was absent from the shell path. cost: about 1 minute. supplying the installed rust toolchain path let the lookup run. naming the missing executable would help.
- broad prerequisite builds consumed about 17 gb before completing. stopped them, reclaimed disposable development artifacts with `cargo clean --profile dev`, and used the warm native-test checkout for a focused swift change. a focused test's prerequisite command and disk estimate would help avoid rebuilding unrelated packages.

## Lean in

- kept the navigation and text-animation candidates unpublished because the saved native checks still fail. reused the pinned bun and the existing upward-menu regression instead of changing assertions to make them pass.

## Needed

- a native-test replay command that survives the runner's next test group.
- affected-suite lookup should report an unavailable cargo executable directly.

## Checkpoints

- recovered the original thread's newer result: export compliance was saved; build 2 showed ready to submit and belonged to the internal tester group. the group contained only its invited owner. no browser or account change in this resumption.
- app pull requests 12, 13 and 14 and framework pull request 1560 are linked to the resumed thread.
