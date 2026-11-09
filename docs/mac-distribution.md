# Local Mac distribution preparation

Run from this checkout. `scripts/package-macos.sh` consumes an existing Mux `.app`;
it never builds, launches, submits to Apple, installs, or publishes. It uses Bun
and Apple's command-line tools. It does not read private keys or passwords.
Signing can prompt Keychain for access to an existing private key.

## Existing Exact behavior

Inspected in the app's configured `expo-exact` checkout:

- `host/apple/build.mjs`: `mac --bundle --distribution` makes a production-trust
  bundle; ordinary Mac builds carry development trust. Re-signing cannot change
  the trust compiled into a binary. The build prints the bundle path.
- `scripts/exact.mjs`, `release(app)`: selects `EXACT_DEVELOPER_ID` or a local
  Developer ID Application identity, **builds**, copies and strips the bundle,
  saves dSYM symbols, signs, submits a ZIP with `notarytool --wait`, staples,
  creates DMG/ZIP, and assesses the app with Gatekeeper. It uses
  `EXACT_NOTARY_PROFILE` (default `exact-notary`). It has no supplied-bundle or
  offline dry-run path. Do not invoke it for this local-only preparation task.
- `host/apple/assets.mjs`, `signRelease`: exported helper for inside-out hardened
  runtime signing, secure timestamps, and receipt-derived app/helper entitlements.
  This script reuses it rather than maintaining another signing traversal.
- `host/apple/build.mjs` and `bundle.mjs` provide production build receipts and
  distribution receipt sanitization. Supply the distribution build, not a copied
  development or agent bundle. This wrapper does not strip binaries or generate
  dSYMs; retain the original build's symbols separately.

The wrapper deliberately leaves Exact unchanged. It packages only the current
embedded Mac configuration with updates disabled. A future framework API change
may require adapting the helper call; failure stops packaging.

## Current eligibility

Read-only inspection on 2026-11-08 (`security find-identity -v -p codesigning`)
found one Apple Development identity and **zero valid Developer ID Application
identities**. No private key or password was exported. Notary profiles were not
read or authenticated. No notarization eligibility is claimed.

The existing local Mac bundle also has `build.compat.embedded.trust` set to
`development`. It is unsuitable for distribution. A new production build is
required, coordinated with the app owner; this unit did not start one.

## Check and prepare

```sh
./scripts/package-macos.sh --check
./scripts/package-macos.sh --dry-run --app /absolute/path/Mux.app
```

Both commands are read-only and offline, and return nonzero for blockers. With
multiple Developer ID identities, select the SHA-1 explicitly using `--identity`
or `EXACT_DEVELOPER_ID`. Apple Development, ad-hoc, missing and ambiguous identities
are refused. `--help` lists all arguments. Paths with spaces must be quoted.
`--exact2` or `EXACT2` overrides the framework checkout; relative framework paths
are resolved from `apps/multiplexer`, matching the app launcher.

Once the app owner has supplied a production distribution build and a valid
Developer ID Application identity with its private key is installed:

```sh
./scripts/package-macos.sh --prepare \
  --app /absolute/path/Mux.app \
  --identity '<developer-id-application-sha1>' \
  --out /absolute/path/new-mux-package
```

This copies the source, signs nested code then the app, verifies the seal, and
creates `Mux.zip` and a signed compressed `Mux.dmg` containing Mux and an
Applications shortcut. Secure timestamps contact Apple's timestamp service,
but no app bytes are submitted for notarization. The output directory must be
new and its parent must exist. Failed runs leave their partial output for
inspection; rerun with a new directory. No input is modified or output deleted.
The `image/` tree and entitlement plists are staging material, not release files.

**These are candidates, not distributable artifacts.** Local candidate creation
needs a signing identity; production distribution additionally needs Apple's
accepted notarization and valid tickets. Neither an Apple Development signature
nor an ad-hoc signature is a substitute.

## Notarization and release gates

Before any later submission, the owner must authorize uploading and have a
working Apple Developer membership, matching Developer ID certificate/private
key, and a valid `notarytool` Keychain profile. Configure credentials privately
with `xcrun notarytool store-credentials` in an interactive terminal; never put
passwords or API keys in shell arguments, repository files, or chat. Merely naming
`EXACT_NOTARY_PROFILE` does not prove that credentials exist or work.

The following is the later operator sequence, **not performed by this unit**:

1. Submit the candidate ZIP using `notarytool submit` with the Keychain profile
   and wait for `Accepted`. Inspect Apple's submission log on rejection.
2. Staple and validate the ticket on the staged `Mux.app`. Assess that app using
   `spctl --assess --type execute`. Do not proceed on any failure.
3. Recreate the ZIP from the stapled app using `ditto -c -k --sequesterRsrc
   --keepParent`. Copy that stapled app into the package's `image/Mux.app` using
   `ditto`, then recreate the DMG with `hdiutil create -ov -volname Mux -srcfolder
   <output>/image -format UDZO <output>/Mux.dmg`. This replaces the earlier
   candidate DMG so its payload includes the app ticket. Sign the new DMG with
   `codesign --sign <developer-id-sha1> --timestamp <output>/Mux.dmg`.
4. Submit that final DMG separately, wait for `Accepted`, then staple and validate
   its ticket. This avoids assuming a DMG has a ticket merely because its app does.
5. Run the read-only verification gate:

   ```sh
   ./scripts/package-macos.sh --verify \
     --app /absolute/path/new-mux-package/Mux.app \
     --dmg /absolute/path/new-mux-package/Mux.dmg
   ```

   It requires Developer ID authority, secure timestamps, hardened app runtime,
   valid signatures and stapled tickets on both artifacts, DMG integrity, and
   Gatekeeper app and disk-image acceptance. It makes no submission. Gatekeeper
   may consult Apple. It does not authenticate credentials or prove the supplied
   DMG contains that exact app; inspect the mounted image before release.
6. Test the actual downloaded DMG on a clean Mac, including offline launch,
   sign-in, Keychain persistence, messaging, and the intended CPU architecture.
   This script does not turn a single-architecture build into a universal one.
   Preserve original symbols, record version/build, and checksum final artifacts.

Do not distribute intermediate ZIPs or DMGs, and do not disable Gatekeeper to
make an unsigned build appear installable. Hosting and publishing remain separate
owner-authorized steps.

## Updates

Mux currently sets `deploy.store.macos` to `"0"`: the plan is embedded and there
is no configured delivery stream. Exact supports signed plan/TypeScript updates
through `scripts/deploy.mjs`, with compatible binary cohorts and a trusted
publisher. It is not a general full-app binary updater. No Sparkle framework,
`SUFeedURL`, or appcast setup was found in the inspected Mac host/release scripts.

Enabling Exact delivery would need an approved supported store/composition,
a reachable deployment origin, a publisher signing key held outside git, trusted
public keys in `deploy.signing`, an authenticated publisher receipt (or deliberate
new-stream genesis), and a new production binary. The current app includes native
modules; confirm this composition is supported before changing stores. A full-app
updater additionally needs a chosen updater implementation, signed update
artifacts, a hosted feed, version policy and rollback testing. None is configured
or added here. Manual notarized downloads remain the proposed first release path.

## Local verification performed

On 2026-11-08, `bash -n scripts/package-macos.sh` and `git diff --check`
passed. A temporary fixture harness passed 14 checks covering help, unknown and
missing arguments, conflicting modes, missing bundle, a production-fixture
dry-run, existing/relative output refusal, missing DMG, ad-hoc identity refusal,
development-trust refusal, real missing Developer ID refusal, and the existing
local development bundle's refusal. Three final checks passed for direct and
symlinked output inside the source app, plus the production-fixture dry-run.
Fixtures used a fake identity listing and a local Mach-O executable; they did
not use or create signing credentials. No signing, timestamping, notarization,
overwrite, or candidate generation ran. Real signing/DMG creation and accepted
notarization remain unverified until the prerequisites above are supplied.
