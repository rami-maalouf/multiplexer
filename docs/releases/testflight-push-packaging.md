# TestFlight push packaging

Historical implementation/upload receipt. Statements below describe this work
window, not current public availability or upstream PR state. See
[installation status](../install.md) and the latest entries in
[the plan](../../tasks/plan.md) for subsequent packaging and gateway work.

Source-only implementation, starting at `251a157bef2e8afc30478b71748ecfc999513f7a`.
No native build, export, upload, simulator or external configuration was performed.
ShellCheck could not run: its mise shim has no configured version; Bash syntax
checks passed.

## Reproduction

Read-only inspection of `/tmp/mx-testflight-qHJ5Ku/Mux.xcarchive` (0.1.0, build 3)
found no `PlugIns/*.appex`. Its app signature contained only the team-prefixed
application identifier, team identifier and `get-task-allow: false`. APNs, App Group
and Keychain-group entitlements were absent. App, ExactModules and ExactVideo dSYMs
were present. The artifact tests reproduce missing extension, shared entitlements,
release registration and extension dSYM failures against that archive. This preserves the earlier upload
receipt; upload success did not establish push packaging.

## Implementation

`testflight.sh` now calls the shared extension packager before export. Its `--store`
mode takes a dSYMs directory and app path, uses the device SDK with a separate cache,
and installs nothing. It needs no development profiles. The extension inherits the
app's version/build and minimum OS. Swift's `-g` emits its dSYM, copied alongside the
existing app and framework dSYMs. Both products are ad-hoc signed, nested first,
with distribution entitlements for Xcode's automatic signing at export:

- app: `com.ramimaalouf.multiplexer`, production APNs;
- extension: `com.ramimaalouf.multiplexer.notifications`;
- both: `group.com.ramimaalouf.multiplexer`, Keychain access group
  `3V2UU7RRK9.com.ramimaalouf.multiplexer`, team `3V2UU7RRK9`, no debugger grant.

The extension's shared-session configuration keeps the existing identifiers.
Simulator and development-device modes retain their installation behavior and
sandbox push. Release builds now execute the same token-registration code as
development builds; account safety checks remain in place.

## Parent-owned gates

The pinned Exact checkout `exact2-mx-testflight` still has an archive refusal in
`host/apple/activities.mjs` (`assertActivityRefusals`), called by `bundle.mjs` for
archives: it scans binaries for `registerForRemoteNotifications`. Removing the
release-only refusal in the app exposes that framework restriction. The parent
must resolve it in its separately owned framework lane before a fresh archive can
succeed. No selector hiding or framework modification is included here.

Sygnal currently serves only sandbox APNs. The parent must configure the production
key and gateway app `com.ramimaalouf.multiplexer.ios` separately, verify distribution
profiles for both identifiers grant the shared groups, and prove locked-phone
TestFlight delivery with test accounts. This implementation alone is not deploy-ready.

Lightweight checks (5 pass; artifact cases skipped unless supplied):

```sh
bun test scripts/testflight-push.test.ts
git diff --check
```

After framework resolution and CPU scheduling, prepare the copied SDK in the parent
checkout as usual and run (choose the next unused build number):

```sh
./scripts/setup-matrix-sdk.sh
EXACT2=/path/to/approved-exact ./scripts/testflight.sh 4 --archive-only
```

Use the printed work directory below. Archive-only writes export options with
`destination: export` and stops before Xcode export or provisioning updates.

```sh
MUX_PUSH_ARCHIVE=/tmp/mx-testflight-XXXXXX/Mux.xcarchive bun test scripts/testflight-push.test.ts
xcodebuild -exportArchive -archivePath /tmp/mx-testflight-XXXXXX/Mux.xcarchive -exportPath /tmp/mx-testflight-XXXXXX/out -exportOptionsPlist /tmp/mx-testflight-XXXXXX/export.plist -allowProvisioningUpdates
unzip -q /tmp/mx-testflight-XXXXXX/out/Mux.ipa -d /tmp/mx-testflight-XXXXXX/exported
MUX_PUSH_ARCHIVE=/tmp/mx-testflight-XXXXXX/Mux.xcarchive MUX_PUSH_EXPORTED_APP=/tmp/mx-testflight-XXXXXX/exported/Payload/Mux.app bun test scripts/testflight-push.test.ts
```

The read-only artifact gates check bundle/version agreement, shared session settings,
production and shared entitlements, release registration selector, strict signatures, matching Mach-O/dSYM UUIDs,
and both exported provisioning profiles' distribution grants. They do not establish
runtime token callbacks, gateway delivery or notification content. The signed export
and physical-phone proof remain mandatory before claiming readiness.

The parent also owns task tracker updates, Exact feedback records/publication, main
integration, authoritative validation and the canonical commit. This lane's ownership
excludes those files and actions.
