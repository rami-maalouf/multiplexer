# Build your own iPhone app

Use your own Apple signing identity and push gateway. Your homeserver handles
messages and bridges; the gateway forwards notification identifiers to Apple.
This path does not require giving AppDrop access to your Apple account.

## Before building

- Set up your Matrix server and bridges using [the server guide](self-hosting.md).
- Prepare the native tools and pinned framework using [CONTRIBUTING.md](../CONTRIBUTING.md).
  The bundled Exact integration patch replaces the old manual patch request.
- Have an Apple Developer Program team, its ten-character team ID, and a unique
  reverse-domain bundle ID, such as `org.example.mux`. Apple's
  [capability matrix](https://developer.apple.com/help/account/reference/supported-capabilities-ios)
  describes which memberships support push, App Groups and Communication Notifications.
  A free personal signing account is not the push-capable distribution path.
- Choose an HTTPS gateway endpoint ending in `/_matrix/push/v1/notify`.
  Do not put passwords or APNs keys in the app configuration.

Keep the identity of an installed app stable: changing its bundle ID creates a
different app with different storage and signing. The maintainer's default build
continues to use its existing identity.

## Configure once

From the repository root, substitute your values:

```sh
bun scripts/configure-ios.ts \
  --team-id ABCDE12345 \
  --bundle-id org.example.mux \
  --push-gateway https://push.example.org/_matrix/push/v1/notify
```

This saves `ios.config.local.json` (gitignored) and synchronizes the app manifest.
Alternatively, copy `ios.config.example.json` to `ios.config.local.json`, edit
its three fields, then run `bun scripts/configure-ios.ts`. The tracked
`ios.config.json` holds the maintainer's existing defaults. `MUX_IOS_CONFIG`
can name another config file for automation.

The extension ID, App Group, Keychain group, session service and sandbox/production
pusher IDs are derived from that configuration. The final bundle carries the
gateway and shared-session metadata for the native app and notification service.
Do not change Swift or shell constants to make your build work. Invalid settings
and a mismatched manifest stop before building.

## Apple setup

In [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list),
register these resources for your team:

| Resource | Example |
|---|---|
| Main App ID | `org.example.mux` |
| Notification service App ID | `org.example.mux.notifications` |
| App Group shared by both IDs | `group.org.example.mux` |
| Shared Keychain group | `<TEAM_ID>.org.example.mux` |

Enable **Push Notifications** and **Communication Notifications** on the main
App ID, and **App Groups** on both IDs. Assign the same App Group to both.
Create a development profile for each ID covering your iPhone and signing
certificate. Regenerate profiles after changing capabilities. For TestFlight
or App Store builds, use matching distribution profiles; Xcode can manage them
when signed in to an authorized developer account.

The APNs authentication key belongs on your gateway server. Keep its `.p8` file
out of this repository, the IPA, terminal output and chat. Match the key's team,
topic and environment restrictions to your chosen App ID.

## Gateway setup

Run a Matrix push gateway such as Sygnal behind HTTPS. Configure two app routes
with your bundle ID: `<bundle>.ios.dev` for sandbox APNs and `<bundle>.ios` for
production APNs. Both use your main bundle ID as the APNs topic and your own
Apple team. The upstream [Sygnal sample](https://github.com/matrix-org/sygnal/blob/main/sygnal.yaml.sample)
documents the complete server configuration.

```yaml
apps:
  org.example.mux.ios.dev:
    type: apns
    platform: sandbox
    topic: org.example.mux
    team_id: YOURTEAMID
    key_id: YOUR_KEY_ID
    keyfile: /data/apns-sandbox.p8
  org.example.mux.ios:
    type: apns
    platform: production
    topic: org.example.mux
    team_id: YOURTEAMID
    key_id: YOUR_PRODUCTION_KEY_ID
    keyfile: /data/apns-production.p8
```

Use keys permitted for each route's environment. Protect the key files so only
the gateway can read them. Your homeserver must be able to reach the HTTPS
gateway endpoint. The app registers an `event_id_only` pusher; notification text
and photos are fetched on the phone from your homeserver. Running Synapse alone
does not configure this Apple delivery path.

## Install on your own iPhone

Download the two development profiles from Apple. Find your device ID with
`xcrun devicectl list devices`, then run from the repository root:

```sh
APP_PROFILE=/absolute/path/App.mobileprovision \
EXTENSION_PROFILE=/absolute/path/Notifications.mobileprovision \
bun scripts/install-ios.ts --device <iphone-udid>
```

The installer checks both profiles against your configuration and device before
building. Expired profiles, a different identity/team, missing shared access or
missing notification capabilities stop the operation. It builds, packages the
service, signs and installs the app. You do not need a preview service for this.

For simulator push development, use `bun scripts/install-ios.ts --sim <udid>`.
Simulator entitlement storage has a fixed capacity; an unusually long bundle ID
may not fit, and the packager reports this rather than producing a broken build.

## Share builds with others

For TestFlight or App Store distribution, use the same configuration:

```sh
./scripts/testflight.sh <next-build-number> --export
```

This exports a signed IPA without uploading. Omit `--export` when ready to upload
through the configured Apple account. TestFlight testers do not need to build
their own app or provide an Apple Developer team. For self-hosted forks, each
operator builds with their own Apple identity and gateway as described above.

`bun scripts/preview-ios.ts <next-build-number>` produces a complete IPA for a
preview service to sign. It uploads nothing. A service must retain the app owner's
team, bundle identity, extension and shared entitlements. AppDrop's optional
owner-team mode requires separate credential authorization; it is not required
for self-hosting. Its recipient-signing flow is not a substitute for this setup.

## Verify the installed build

Open the installed app, sign in to a test account on your server and allow
notifications. Background the app, lock the phone, and send a new message from
another test account. Check sender, text and photo, then repeat after terminating
the app. Open Mux again after changing notification permission or reconnecting.

Development installs use APNs sandbox. TestFlight, App Store and owner-signed
distribution previews use production APNs. Test both environments before sharing
a release. A successful build or upload alone does not prove delivery.

If a push does not arrive, check the app's notification permission, the account's
Matrix pusher, gateway route and APNs response. A generic alert with no sender
content points toward extension/shared-session access; no alert at all requires
checking registration and delivery first. Keep tokens and private messages out
of logs you share.
