# TestFlight 0.1.0 (3)

Historical implementation/upload receipt. Statements below describe this work
window, not current public availability or upstream PR state. See
[installation status](../install.md) and the latest entries in
[the plan](../../tasks/plan.md) for subsequent packaging and gateway work.

- uploaded 2026-11-07 at 18:20 UTC with `scripts/testflight.sh 3`.
- source: `f995eeebb654935d503aa2116620c9a2f0d6524f` on `release/testflight-3`.
- integrates app PR13 and PR14 through `7a74799`, plus PR12 `8d8f6bc`.
- framework: clean `exact2-mx-testflight` at `7783ea7012d01f2df8b9b53ce814c9e8337b2aef`. No shared integration checkout, dirty tracing, or unfinished framework candidate was used.
- the only tracked difference from `7a74799` at compilation was `scripts/testflight.sh`, adding framework dSYM copying. Local generated dependency paths point at the stable framework checkout; excluded from commits.
- copied MatrixCore into app before compilation using `scripts/setup-matrix-sdk.sh`.

## Validation

- 13 Bun tests passed.
- `verify ios`: 12 tests passed, light/dark checks clean, 14 largest-text screens without overflow; 195.7 s including build-lock wait.
- signed-in test-account smoke: group-filter list, chat composer and group info display screenshots inspected. Composer has a layout immediately after chat navigation; info says 2 members and has two member rows. This does not repeat the prior 60 fps cold-open recording or the bridged-group fixture test.
- screenshots: `/tmp/mx-release3-groups.png`, `/tmp/mx-release3-chat.png`, `/tmp/mx-release3-info.png`.
- test account signed out at completion; owned simulator shut down.
- simulator: MX demo `1A0C8776-65D7-4376-BB24-EF4D0951445E`.
- previous core evidence remains 15 focused tests passed; full 129-test run had two failures that passed in isolation. This release lane did not repeat or erase that limitation.
- verification properties are observed suggestions, not proofs; Lean semantics did not run because `lake` is unavailable.

## Archive and upload receipt

Local archive: `/tmp/mx-testflight-qHJ5Ku/Mux.xcarchive`.
Upload log: `/tmp/mx-release3-upload.log`.
Verification log: `/tmp/mx-release3-verify.log`.

The archive's Info.plist reports build 3. Symbols:

- Mux: `10C26EC7-CF8B-314B-A861-2271327A1105`.
- ExactModules: binary and dSYM UUID `E0967682-05A7-340F-BD87-FBA78A8C4B66`.
- ExactVideo: binary and dSYM UUID `9DE4A308-6FA6-37B4-8445-BBFF483FC91E`.

Xcode receipt:

```
Uploaded package is processing.
Upload succeeded.
Uploaded Mux
** EXPORT SUCCEEDED **
uploaded 0.1.0 (3).
```

No missing-symbol warning appeared. Acceptance here means the upload succeeded; external beta review and group assignment are owned by the coordinator. No export-compliance answer was changed.

## App PRs

- https://github.com/rami-maalouf/multiplexer/pull/12
- https://github.com/rami-maalouf/multiplexer/pull/13
- https://github.com/rami-maalouf/multiplexer/pull/14

All were open with successful GitGuardian checks when inspected. PR14's release input includes local documentation through `7a74799`, beyond the remote head `036f395` observed at intake. No PR polling or merge into main was performed.
