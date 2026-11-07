# An app cannot receive remote push: no token, no aps-environment, and the archive check refuses the call

**Status:** Open
**Systems:** notifications, apple host, signing
**Severity:** P2
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

A chat app needs remote push: the server sends a push for each new message, and the phone shows it
while the app is closed. Exact has local notifications and the permission (`@exact/notifications`),
but nothing of remote push (LLP 1133.004 section 9: designed, "Nothing of it is built here"):

- **No token.** There is no send that answers the APNs device token, and the host's app delegate
  has no `didRegisterForRemoteNotificationsWithDeviceToken`. The app's native module adds both
  delegate callbacks to the host's app delegate class at run time (`class_addMethod`), then calls
  `UIApplication.shared.registerForRemoteNotifications()`. It works on the Simulator (a sandbox
  token arrives), but it depends on the host's private class keeping no callbacks of its own.
- **No `aps-environment`.** The build signs `aps-environment` only for a Live Activity with
  `push: true` (`host/apple/build.mjs`, `entitlements`). Without it, iOS answers "no valid
  aps-environment entitlement string found for application", on the Simulator too. No manifest key
  or grant adds it for an app.
- **The archive check refuses it.** An archive is refused when the binary references
  `registerForRemoteNotifications` (`host/apple/activities.mjs`), so an app that registers cannot
  go to TestFlight. A development build is not checked.
- **A received push reaches no app code** (no `willPresent` or `didReceive` hatch for a push the
  app did not post); not needed yet here, but the next step of the same feature.

Cost: about 30 minutes to find each part and write the run-time workaround, and the TestFlight
path is closed.

## What would help

LLP 1133.004 section 9 built: a `subscribePush()` send that answers the token as a live source, a
grant line that signs `aps-environment` (development for a development profile, production for a
distribution one), and the archive check allowing the call when that grant is declared.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0`, iOS 26.5 Simulator: the token callback added at run
time received a 64-byte sandbox token once the binary's simulated entitlements had
`aps-environment`; without it, the error above.

## Evidence (2026-11-07): it also blocks an install-link archive

Once the roster check passed (finding 126's local fix), `ios --device --archive <out.ipa> --unsigned`
stopped at `ExactModules.framework/ExactModules: registerForRemoteNotifications refused (LLP 1126.001
WP9)`. For that one archive, the call was replaced by an immediate "no token" answer in an
uncommitted copy (a re-signing service signs with the recipient's own Apple ID, which has no push
entitlement, so nothing was lost). The archive was then made. The refusal applies to every archive,
also to an app with no Live Activity, which is what the WP9 ruling is about.
