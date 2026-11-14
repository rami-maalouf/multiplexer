# Opening a chat from an iPhone notification

Push-capable builds attach a conversation destination in the notification service
extension. A tap uses the app's existing `notificationclick` handler to open that
room, including when it is not yet in the loaded inbox. This applies to development,
ad hoc and distribution builds that retain the packaged extension and push signing.

The extension captures the saved Matrix account before fetching or decrypting the
message. It attaches the destination before saving the initial fallback, so a timeout
or unavailable store can still produce a tappable "New message" banner. Sender-photo
styling preserves the same metadata. The app checks the account again when tapped;
signed-out or different-account notifications do not navigate. A signed-out tap is
not replayed after a later sign-in.

Opening a chat saves the current draft and resets the navigation stack to the inbox
before adding the destination. Chat state is shared across the stack; leaving an old
room underneath the new one would keep displaying the previous conversation.

`NotificationActivation.swift` is a small adapter to Exact's private activation
format. Rami approved this dependency on 2026-11-14. It supplies the `main` session,
a cross-process identity, and JSON-encoded `notifications.notificationclick`
arguments. Exact owns launch-time queuing and duplicate callback suppression.
Do not replace this with an unscoped `navigate` URL: that bypasses the account check.

## Regression checks

On the Mac, set `EXACT2` to the framework checkout used to build the app:

```sh
EXACT2=/path/to/exact bun test scripts/notification-activation.test.ts \
  scripts/notification-service.test.ts apps/multiplexer/notification-target.test.ts
SIMULATOR=<owned-booted-udid> bun test scripts/communication-notification.test.ts
```

The receiver test compiles Exact's actual `Notify.swift` with the app's adapter.
Its source hash pins the private contract to the validated receiver. When upgrading
Exact, inspect changes to notification delivery and startup, rerun warm and terminated
app taps, then update the hash only after compatibility is established. The service
test compiles the actual extension with controlled session/SDK boundaries and proves
that initial expiration, store failure and signed-out fallbacks preserve their rules.

For manual acceptance, install with `scripts/install-ios.ts`, sign in with an approved
test account, and send a message from another test account. Tap a newly delivered
system banner while the app is on Settings, in another chat, and terminated. Confirm
the intended chat opens each time. Also check a fallback banner and an old-account
banner. `simctl push` does not run the service extension; use real sandbox APNs for
the complete delivery path, or clearly distinguish an injected enriched-payload tap
from an actual extension run.

Validated on 2026-11-14 with iOS 26.5 on an owned simulator and approved test users:
real sandbox APNs taps opened the destination from Settings, another conversation,
and a terminated app. An injected enriched fallback opened its room; an injected
different-account banner left the inbox unchanged. The native service fixture
separately verified creation of timeout and unavailable-store fallback metadata.
Physical-device and distribution-channel tap delivery were not rerun for this change.

## Limits

Notifications already delivered by an older build retain their old metadata.
If iOS does not run the extension, or its shared Keychain is unavailable before the
first device unlock, the app has no trustworthy account-scoped destination. Those
notifications still show their fallback text but cannot use this routing adapter.
This change opens the conversation; it does not scroll to a historical event or
change foreground-banner suppression.
