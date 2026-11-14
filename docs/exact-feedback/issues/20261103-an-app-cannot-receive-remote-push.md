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

## Evidence (2026-11-07): the app's own module has no development flag

For a TestFlight archive, the app needed to keep its push-registration call out of the archive
and keep it in development builds. Packages compile with `-D EXACT_DEVELOPMENT` in a development
build. The app's own `modules/apple/` Swift compiles with no such flag, so the app had no
compile-time way to do it. Local fix in exact2 (`8e547ca606`, branch `local/mx-testflight`):
the app module's compile takes the same flag as packages, and `docs/reference.md` says to put a
development-only call inside `#if EXACT_DEVELOPMENT`. With that and the `#if` in the app, the
archive passed with 0 hits of the refused name in its binaries, and a development Simulator build
kept the call. Not yet a pull request. About 15 minutes.

## Evidence (2026-11-07): it also blocks an install-link archive

Once the roster check passed (finding 126's local fix), `ios --device --archive <out.ipa> --unsigned`
stopped at `ExactModules.framework/ExactModules: registerForRemoteNotifications refused (LLP 1126.001
WP9)`. For that one archive, the call was replaced by an immediate "no token" answer in an
uncommitted copy (a re-signing service signs with the recipient's own Apple ID, which has no push
entitlement, so nothing was lost). The archive was then made. The refusal applies to every archive,
also to an app with no Live Activity, which is what the WP9 ruling is about.

## Evidence (2026-11-07): delivery works through the development workaround

At integration checkout `4251663c25`, the custom registration callbacks and post-build
extension delivered real APNs notifications while the app was terminated. Plain and
encrypted messages showed their sender and text on an iOS 26.5 Simulator; extension
processing took 120 to 227 ms with a 17 to 19 MB peak footprint. A person confirmed a
fallback banner on a locked physical iPhone using a development-signed build.

This verifies the workaround, not framework support. The host's notification presenter
still accepts only its own activation envelope, and exposes no app-defined remote tap
or foreground-presentation callback. No private activation key was used as a workaround.

## Evidence (2026-11-14): a remote tap silently restores the previous screen

At integration checkout `b46687753f73fbe3473e661d59657592bb5b7572`, a remote banner
with a room and event id opened the previous settings screen. A native probe compiling
`Notify.swift` reproduced the missing activation event. The receiver requires its
private `userInfo["exact"]` entry, including string session/owner fields and a
cross-process identifier; its event arguments must be a JSON-encoded string.

Tracing the receiver, startup order and module activation queue took about ten
minutes. With maintainer approval, the app now constructs that pinned format in its
service extension, before asynchronous enrichment, and tests it against the actual
receiver. This is an app workaround, not a supported remote-notification API.
A documented remote activation constructor would remove the private-format dependency.

A first payload used `@exact/notifications`, matching the manifest/import name, but
the runtime reported `@exact/notifications.notificationclick: no handler hears it`.
The runtime identity is the short `notifications`. A receiver-only fixture accepts
either string, so real sandbox APNs taps were needed to expose this mismatch. Warm
and terminated-app taps then reached the existing handler. This cost another ten
minutes tracing runtime registration and logs; the constructor should own this name.

## Evidence (2026-11-14): removing delivered remote notifications

Opening a conversation left its delivered banners in Notification Center. The package's
`closeNotification` removes only a caller-known request identifier; remote requests use
system identifiers. Inspecting the native implementation took about two minutes. The app
uses a native delivered-notification query, matches its account-scoped destination, and
removes only matching identifiers. A documented group or metadata-based removal operation
would avoid this additional native bridge.
