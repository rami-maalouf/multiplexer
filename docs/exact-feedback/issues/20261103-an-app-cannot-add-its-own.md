# An app cannot add its own app extension or declare the entitlements one needs

**Status:** Open
**Systems:** apple host, build, signing
**Severity:** P2
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

A notification service extension is how a chat app shows the sender and the text of an end-to-end
encrypted or "id only" push: iOS wakes it with the push, it fetches the message, and it rewrites the
notification. It must be an app extension inside the app (`PlugIns/<name>.appex`), sharing an App
Group and a Keychain group with the app. Exact builds its own extensions (widgets, Live Activities,
the share extension) but an app cannot declare one of its own, and cannot declare the App Group,
Keychain group or `aps-environment` that the app and the extension need.

What the app did instead, after Exact's build (a script of its own):

- compiled the extension with `swiftc` (the same flags as Exact's share extension,
  `host/apple/extensions.mjs` `appexArgs`), with the native module's Swift and its vendor
  library, wrote its Info.plist, and put it in `PlugIns/`;
- for the Simulator, rewrote the app's `__TEXT,__entitlements` section in place: the Simulator
  reads entitlements from there, `segedit -replace` refuses it ("can't replace section ... because
  it requires relocation"), and Exact's section is exactly as long as its own plist (462 bytes
  here), so the new entitlements had to be a compact XML plist padded with spaces, leaving out
  Exact's second, legacy Keychain group to fit; then signed ad hoc again;
- for a phone, signed the extension and the app again with explicit profiles (not run yet).

An `exact.mjs agent ios` or `test ios` drive installs Exact's own build over this, so a drive does
not have the extension.

The extension links its own copy of the vendor library, because the native module's code is
linked into Exact's `libexact_modules.dylib` with Exact's runtime: the extension's binary is 73 MB.

Cost: about 90 minutes, and every build now needs the extra script.

## What would help

An app-declared extension in `app.json` (its kind, its sources in the app folder, linked with the
native module's Swift and vendor libraries, or with a shared framework), and declared entitlements
for the app and its extensions: an App Group, a Keychain group and `aps-environment`, signed into
both the simulated and the device signatures. At least: a simulated entitlements section with room
to grow, or a documented hook that runs after the bundle is made and before it is signed and
installed.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0`, iOS 26.5 Simulator: the extension was registered by the
system ("plugin INSTALLED"), and the app's patched entitlements gave it its push token.


2026-11-12 follow-up: a fresh ordinary ios build again contained no remote push or app-group entitlement and no notification extension, replacing a separately packaged build. the app now wraps build plus packaging plus reinstall in one command. a declarative extension and entitlement build would remove this workaround.
