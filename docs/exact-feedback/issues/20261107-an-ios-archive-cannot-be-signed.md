# An iOS archive cannot be signed with a cloud-managed distribution certificate

**Status:** Open
**Systems:** host/apple, build
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-07

## What happened

A chat app needed a TestFlight build. Exact's signed archive (`--device --archive <out.ipa>`)
needs `EXACT_IDENTITY` and `EXACT_PROFILE`: an Apple Distribution identity in the keychain and
an App Store profile file on the Mac. A team that distributes with Xcode's automatic signing has
neither. Xcode signs with a cloud-managed distribution certificate, whose private key never
leaves Apple, and makes the App Store profile when it exports. So Exact's own signed path could
not be used.

The working path, about 10 minutes to find:

1. `--device --archive <out.ipa> --unsigned`.
2. Wrap the app in a hand-made `.xcarchive` (`Products/Applications/<App>.app` and an `Info.plist`
   with `ApplicationProperties`).
3. `xcodebuild -exportArchive -allowProvisioningUpdates` with method `app-store-connect`,
   signing style automatic, destination `upload`.

Step 3 first failed: "Provisioning profile ... doesn't match the entitlements file's value for the
application-identifier entitlement". The unsigned archive's ad hoc signature carries the bare
bundle id as `application-identifier`, not `<team>.<bundle id>`. Re-signing ad hoc with the
team-prefixed value fixed it. Xcode then signed with the cloud-managed certificate and uploaded.

Seen at exact2 `71382b8307` (with a local change, see finding on remote push), Xcode 27.2.

## What would help

- An archive mode that ends in Xcode's export (cloud signing and upload), or an `.xcarchive`
  output beside the `.ipa`.
- When the team is known (the app's development profile names it), the unsigned archive writes
  `application-identifier` as `<team>.<bundle id>`.
- One line in the release docs: what a team with only automatic signing does.
