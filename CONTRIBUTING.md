# Contributing to Mux

Mux is an early project for iPhone, macOS and a Mac command-line client. Start with
[the README](README.md) for capabilities and [the docs index](docs/README.md) for
setup and implementation notes. The original project code is GPL-3.0-only; see
[LICENSE](LICENSE). Third-party licenses and notices still apply.

## Build status and prerequisites

Native development currently needs an Apple silicon Mac, Xcode with the iOS
Simulator, Git, Rust through rustup, and Bun 1.4.2. The app targets iOS 17+ and
macOS 14+. The standalone website needs only Bun. The CLI needs the macOS Swift
toolchain and its own SDK setup, described in [cli/README.md](cli/README.md).

**A public upstream clone is not yet a verified reproduction of the native app.**
The last validated Exact integration is local commit
`8536d208c40f97be3f132ea266d5029e2e3c10ba`, based on upstream
`94b8671f70fe2e25b307a40e7fce66dc27c9f802`. The integration includes local host
fixes and was not available at that commit's public GitHub URL during the
2026-11-10 audit. Ask the maintainer for the integration patches before expecting
native parity. This repository does not vendor Exact or those patches.

The layout below makes the checked-in relative dependency paths resolve:

```text
workspace/
  multiplexer/       # this repository
  exact/
    expo-exact/      # the Exact checkout, including the integration patches
```

Clone [this repository](https://github.com/rami-maalouf/multiplexer) and
[Exact](https://github.com/expo/exact) into those folders. Keep the two repos
separate. From the Exact checkout, follow its README and run:

```sh
bun scripts/exact.mjs setup
bun scripts/exact.mjs setup --check
```

Setup provisions the framework's toolchains, dependencies and pinned Hermes
bundles; ordinary native builds use those bundles offline. Follow the selected
Exact revision's prerequisites rather than installing arbitrary newer tools.

For a different folder layout, Exact's `new <absolute-app-path> --update` command
regenerates the integration. Review the resulting dependency paths, including
`apps/multiplexer/package.json`: `EXACT2` alone does not rewrite Cargo or package
dependencies. Do not edit generated launcher or schema files by hand.

## Run the app

From this repository's root:

```sh
./scripts/setup-matrix-sdk.sh
cd apps/multiplexer
bun install --frozen-lockfile
bun exact.mjs ios --run
```

`setup-matrix-sdk.sh` downloads and checks SDK release `26.10.27` and copies
MatrixCore into the app. Run it again after every edit in `matrix-core/`; otherwise
the app compiles the old copy. Initial native builds can take several minutes.
For push-capable installs, use the complete installer from the repository root:

```sh
bun scripts/install-ios.ts --sim <simulator-udid>
# for a phone, set APP_PROFILE and EXTENSION_PROFILE to development profiles first:
bun scripts/install-ios.ts --device <phone-udid>
```

The installer builds, adds the notification service and shared entitlements, and
reinstalls the signed app. It stops on a packaging failure. Ordinary `exact ios`
and native test/verify commands install a bare bundle, so run the complete installer
again before testing push. Open the installed app once to register with APNs and
allow notifications. Device profiles must cover the phone, App Group and Keychain
group; the app profile must also grant development APNs and Communication
Notifications. Enable that capability on the app identifier, then regenerate its
profile. The installer checks the capability before replacing an existing phone build.

For a preview IPA with the same notification packaging as a release:

```sh
bun scripts/preview-ios.ts <next-build-number>
```

This prints the IPA path and uploads nothing. Use AppDrop's owner-team **People
you approve** mode to retain push identity; ordinary `exact share` omits the
notification packager. For TestFlight/App Store signing without upload, use
`./scripts/testflight.sh <next-build-number> --export`. See the
[distribution requirements](docs/install.md#notifications) before publishing.

For the Mac app, run these from the repository root before `bun exact.mjs mac --run`
in `apps/multiplexer/`:

```sh
./scripts/setup-matrix-sdk.sh
./scripts/build-matrix-sdk-macos.sh
./scripts/setup-matrix-sdk.sh
```

The middle step builds the matching Apple silicon SDK slice; the last step
copies the combined framework. Mac distribution is still experimental; read
[the distribution gates](docs/mac-distribution.md) before sharing a bundle.

Sign in with your own development homeserver and test accounts. Rami's Keychain
entries and live server are not prerequisites available to contributors. GIF
search additionally needs your own KLIPY app key in the gitignored
`apps/multiplexer/.env.local` as `KLIPY_KEY`. The Keychain helper
`scripts/setup-klipy-key.sh` is for checkouts with a configured
`multiplexer-klipy` item; do not expect it to work on a fresh Mac.

For iPhone push, see [installation and push requirements](docs/install.md#notifications).
Changing signing identifiers also requires matching App Groups, Keychain groups,
extension settings and gateway configuration. Re-signing an arbitrary bundle
alone does not establish push support.

## Check a change

From `apps/multiplexer/`:

```sh
bun exact.mjs contract build app.contract --json --errors-only
bun test
bun exact.mjs verify ios
# for a mac-specific change:
bun exact.mjs test mac
```

The Contract gate refreshes generated types and checks TypeScript. Native authored
tests cover signed-out UI; they do not establish authenticated chat behavior.
Some sign-in error tests reach public endpoints and need network access. The web
host has no Matrix SDK and is not a substitute for native app verification.

MatrixCore's live iOS suite sends messages and changes rooms. It defaults to
maintainer test accounts, so configure your own isolated accounts first:

```sh
MATRIX_TEST_USER=@test1:example.com MATRIX_TEST_USER2=@test2:example.com \
  MATRIX_TEST_HOMESERVER=example.com SIMULATOR=<your-simulator-udid> \
  scripts/mx-lock.sh matrixcore contributor -- ./scripts/test-matrix-core.sh
```

Store their passwords privately in Keychain service `multiplexer-test-account`,
with each full Matrix ID as the account. Read the fixtures before running the
full suite: they assume bridge features and server configuration that a generic
homeserver may not provide. Do not run them against personal chats. The CLI live
suite has its own designated accounts and write-policy rules.

After Mac SDK setup, the default native Mac core suite needs no credentials:

```sh
scripts/mx-lock.sh matrixcore contributor-mac -- scripts/test-matrix-core-macos.sh
```

For website edits, follow [website/README.md](website/README.md), run its build,
and inspect desktop and phone widths. Documentation-only changes need working
links and accurate commands; they do not require a full native build.

## Structure and review

Only MatrixCore calls matrix-rust-sdk. Native modules call MatrixCore; Contract
and TypeScript own the UI. Keep that boundary and the existing storage/signing
identifiers intact. [AGENTS.md](AGENTS.md) contains the maintainer's automation
rules, shared-resource locks and account safety rules. Its absolute paths and
server inventory describe the maintainer's machine, not a fresh checkout.

Use a focused branch and a conventional, lowercase commit message. In a pull
request, explain the behavior changed and the checks actually run. Include
screenshots for UI changes and name any platform or account state left untested.
Leave dated release receipts and historical observations intact; add a correction
or a new dated status entry when they have been superseded.

For a bug report, include the app version/build, OS, steps, expected behavior and
actual behavior. Remove contact names, message bodies, access tokens and login
cookies from screenshots and logs. Report credential exposure privately to the
maintainer before posting details in a public issue. Never commit `.env.local`,
server `vars.yml`, SDK stores, recovery keys or database backups.
