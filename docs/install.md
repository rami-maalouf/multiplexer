# Install Mux

Status reviewed on 2026-11-10. Mux is early software; keep another Matrix client
available while trying it. It needs your own Matrix account and homeserver.
To add WhatsApp, Instagram or LinkedIn, the homeserver also needs the relevant
bridge. [The self-hosting guide](self-hosting.md) describes that setup.

## iPhone

The app targets iOS 17 or newer. The existing
[AppDrop preview link](https://appdrop.app/d/nb2nfrv68c) is the shared install path;
follow its current pairing and signing instructions. The URL responded during
this audit, but pairing and installation were not exercised. Preview access and
signing can change, so a link alone does not establish notification support.

TestFlight archives have been uploaded, including build 4 on 2026-11-08, but this
repository does not publish a verified public TestFlight invitation or App Store
listing. Upload receipts do not establish beta approval or availability.
If the preview link is unavailable, use [the source build guide](../CONTRIBUTING.md)
or another Matrix client. Native source reproduction still requires the Exact
integration patches described there.

In Mux, enter your base Matrix domain, user name and password. The domain must
serve the Matrix well-known client configuration, or enter the homeserver's
hostname directly. Your full Matrix ID keeps its original domain.

## Mac

A native Mac app exists, targeting macOS 14+ on Apple silicon. Desktop navigation,
messaging, search and file drops have development/test-account evidence. A public
signed, notarized Mac download and clean-Mac installation have not been verified.
There is no configured automatic update channel. Build locally with
[CONTRIBUTING.md](../CONTRIBUTING.md); see [Mac distribution](mac-distribution.md)
for the remaining release gates. Do not disable Gatekeeper to work around an
unqualified download.

The separate [`mx` command-line client](../cli/README.md) also runs on Apple
silicon Macs. It does not require the Exact UI framework.

## Browser and Android

Mux does not ship a working Matrix web or Android client. Use a compatible Matrix
client, such as [Element Web](https://app.element.io) or
[Element X](https://element.io/app), with the same homeserver and account.

## Notifications

The iPhone app uses APNs and a Matrix push gateway. Sender/text notifications on
a locked iPhone were confirmed on the maintainer's development build. Production
gateway configuration and extension packaging exist, but TestFlight delivery and
notification support for a re-signed AppDrop preview are not established by those
development tests.

For a development build installed from a Mac, use
`bun scripts/install-ios.ts --device <phone-udid>` from the repository root, with
`APP_PROFILE` and `EXTENSION_PROFILE` set to the matching development profiles.
The ordinary framework build does not package remote push. See
[the build guide](../CONTRIBUTING.md#run-the-app). After installing, open Mux once
and allow notifications. Registration retries after a transient failure while
Mux is visible and runs again when you return to the app. Sender photos use the
iOS communication-notification layout, with locally rendered initials when the
profile has no usable photo. Photo fetching has a short deadline and the message
still arrives if it fails. This does not request Contacts access. Development
profiles must include the Communication Notifications capability.

**The gateway URL is currently fixed in the app**, in
[`PushRegistration.swift`](../apps/multiplexer/modules/apple/PushRegistration.swift),
to `sygnal.ramimaalouf.com`. Signing in to another homeserver does not change it.
The app registers an `event_id_only` pusher: the gateway receives room/event IDs
and device routing data, and sends a generic alert through Apple. The notification
extension fetches the event from the homeserver and renders its content on-device.
The gateway is separate infrastructure from your homeserver; running your own
Synapse does not make the shipped push path fully self-hosted.

For your own build and gateway, change that source URL and configure Sygnal for
your Apple team, bundle ID and APNs environment. Configure the app and notification
extension with matching App Group and Keychain entitlements and provisioning.
The checked-in extension packager is specific to the maintainer's signing
identifiers, so adapt and review it as well. The server inventory is an operator
example, not a drop-in public push service or availability promise.

On Mac, notifications are local and need the app running. A real macOS system
banner remains unverified in the recorded development checks.
