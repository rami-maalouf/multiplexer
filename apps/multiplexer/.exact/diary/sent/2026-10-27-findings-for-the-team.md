surfaces: ios
agent: Claude Code, Claude Opus 5.5
task: turn an app's Exact friction into issue-ready findings, rechecked at the latest exact2

### Rough
- `feedback send` moved the sent entries into `.exact/diary/sent/`. This app keeps its diary in git, so `git status` showed each sent entry as deleted and `sent/` as new. ~2 min. `docs/diary.md` says `.exact/` is gitignored, so a tracked diary is not expected. What would have helped: the send's output saying where the entries went, or a note in `docs/diary.md`.

- There is no private way to give the team issue-ready findings. exact2's `issues/` takes them through a pull request, which is public (the repo is public, and the person's account can only read it), and `feedback send` takes only diary entries. So the 15 findings below travel inside this entry. What would have helped: `feedback send` taking issue files beside the diary (checked with `issue.mjs check`), so the team can move them into `issues/` as they are.

### Lean in
- `bun <exact2>/scripts/issue.mjs check` works from any folder that holds an `issues/` folder, so the drafts were checked in the app's own repo with the team's own tool ("Issue format passed").
- Every finding could be rechecked against the newest exact2 from git alone (`git diff --stat <old> origin/main -- <paths>`), with no rebuild.

### Needed
- none

### Checkpoints
- driving the app (`exact.mjs agent`, `exact.mjs test`): smooth

### Issue-ready findings

These are the Rough entries of the four entries sent before this one (receipt `4c8a0a07-60a8-466e-ae9a-bef9a0b29f82`), each written as an exact2 issue file and checked with `scripts/issue.mjs check`. Each was rechecked on 2026-10-27 against exact2 `cee509ac82`: the code or docs that each one names had not changed, unless its Evidence says otherwise. P2 marks the two that cost the most.

1. Each edit to a native module compiles all of `modules/apple` again, a vendor's large Swift included (`issues/20261027-module-swift-recompiles-vendor-bindings.md`)
2. An authored test cannot read a secret, so `verify` never reaches the screens behind a sign-in (`issues/20261027-authored-tests-cannot-read-a-secret.md`)
3. A native module can use only real files in `modules/apple`: no links and no local Swift package (`issues/20261027-module-swift-only-from-modules-apple.md`)
4. A native module cannot keep a secret in Exact's store, so its own Keychain items outlive a fresh drive (`issues/20261027-native-module-has-no-secret-store.md`)
5. The editor cannot resolve native module Swift, so every line shows an error (`issues/20261027-editor-cannot-resolve-module-swift.md`)
6. `state` prints the value that a password field is bound to (`issues/20261027-agent-state-prints-a-password.md`)
7. A `role="status"` readout that holds a `progress` is hidden from the iOS bar, with no warning (`issues/20261027-ios-bar-hides-a-status-readout-with-progress.md`)
8. An app whose data comes from an iOS module cannot say that it runs on iOS only (`issues/20261027-an-app-cannot-say-it-runs-on-ios-only.md`)
9. The native-module recipe leaves out the module's folders, its Swift mode, and how `clock data` treats `later` (`issues/20261027-native-module-recipe-gaps.md`)
10. `contract vocab` names a tag or a property but not its attributes or values (`issues/20261027-vocab-gives-no-attributes-or-values.md`)
11. `prefer root-font-size` enlarges Exact's text but not native fields or list footers (`issues/20261027-prefer-root-font-size-leaves-native-text.md`)
12. The `chat-thread` recipe's bubble uses `overflow-wrap="anywhere"`, which `verify ios` reports (`issues/20261027-chat-thread-recipe-breaks-inside-words.md`)
13. Four agent messages that could say what to do next (`issues/20261027-small-agent-drive-messages.md`)
14. An app that uses exact2 by path has no safe way to follow a rewritten `main` (`issues/20261027-apps-outside-exact2-cannot-follow-a-rewritten-main.md`)
15. After `update`, `lock` reports "no changes" for a `Cargo.lock` that `update` just rewrote (`issues/20261027-update-and-lock-disagree-about-cargo-lock.md`)

````markdown
# Each edit to a native module compiles all of `modules/apple` again, a vendor's large Swift included

**Status:** Open
**Systems:** Apple host build (`host/apple/build.mjs`), native modules, Exact packages
**Severity:** P2
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-10-27

## What happens

The app wraps a third-party Rust library. Its static xcframework and the 2 MB of Swift
bindings that the vendor generates are in `modules/apple/`, beside the app's own small
module file. `host/apple/build.mjs` compiles every top-level `.swift` file there as one
module (`moduleArgs`: one `swiftc` call, `-O`). So a one-line edit to the app's file
compiles the 2 MB of bindings again. The build line's `arms` time was 41.7 s and 31.0 s
for such edits on the iPhone 17 Pro simulator. Every Swift edit in two tasks paid it. An
edit to `app.contract` or `app.ts` took seconds.

## What would help

- Compile Swift that does not change (a vendor's) once, as its own module, and reuse its
  object while its sources are the same. The app's own file then compiles alone.
- Exact packages already compile as their own Swift modules (`placePackages`). From
  reading `build.mjs`, each package compiles again whenever the module arm rebuilds, and
  the arm's key holds the module's and the packages' sources together. Not measured. If a
  package were cached by its own sources, a vendor's bindings could live in one.
- `docs/recipes/native-module.md` does not mention packages, so an author with a vendor
  library does not find them.

## Evidence

Seen at exact2 `65577096ed`. `host/apple/build.mjs` is unchanged at `cee509ac82`.
````

````markdown
# An authored test cannot read a secret, so `verify` never reaches the screens behind a sign-in

**Status:** Open
**Systems:** authored tests (`app.test.contract`), `verify`, agent
**Severity:** P2
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-10-27

## What happens

The app signs in to a real server with a password, through a native library (not
`fetch`, so a fake server cannot stand in). The password cannot be in
`app.test.contract`, which is in git. The test grammar (`docs/contract-grammar.md`,
"Authored tests") has no step that reads a value from the environment or the Keychain.
So every authored test stays on the sign-in screen, and `verify ios` checks only that
screen.

The chat list behind the sign-in drew each row's time over the chat's name at the
largest text size. `verify ios` said "nothing spills". Only a drive at the simulator's
own largest size (`xcrun simctl ui <udid> content_size
accessibility-extra-extra-extra-large`) found it.

Workaround: drives that type the password from a shell variable
(`pw="$(security find-generic-password …)"`, then `"type password $pw"`). The drive masks
the field, but `state` does not (`20261027-agent-state-prints-a-password.md`).

## What would help

A test step that types a named secret from the environment, masked in every report and
log, for example `type "password" env "APP_TEST_PASSWORD"`. A test whose variable is not
set would be skipped and say why. `verify` would then check the screens behind the
sign-in, in both schemes and at every text size.
````

````markdown
# A native module can use only real files in `modules/apple`: no links and no local Swift package

**Status:** Open
**Systems:** source capture (`js/bake`), native modules, docs (`docs/recipes/app-json.md`)
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-10-27

## What happens

- The vendor's xcframework (an 84 MB static library) and its Swift bindings were linked
  into `modules/apple/` with symbolic links, to keep them out of the app folder and out of
  git. `contract build` refused: `source links are not captured:
  …/modules/apple/<a binding>.swift`. `js/bake/src/lib.rs` refuses every link in the app
  except `.md` and `.txt` files.
- The app's wrapper around the library also builds as a Swift package, for its own
  XCTests on the simulator. A module cannot depend on that package, so the same files
  compile in both places and import the library behind `#if canImport(…)`.

Workaround: a setup script copies the library, the bindings and the wrapper into
`modules/apple/` as APFS clones (`cp -c`), and git ignores the copies. After each edit
to the wrapper, the script must run again, or the app builds the old copy. Cost: about
20 minutes, then one more step on every edit.

## What would help

- The capture following links inside `modules/apple/` (Swift files and xcframeworks are
  not data-module sources), or a message that names the rule and the folder.
- A documented way to compile Swift from outside `modules/apple/`: source folders listed
  in `app.json`, or a local Swift package as a dependency.
- `docs/recipes/app-json.md` saying "real files, no links" for the `modules` folder.

## Evidence

Seen at exact2 `65577096ed`. The refusal is still in `js/bake/src/lib.rs` at `cee509ac82`.
````

````markdown
# A native module cannot keep a secret in Exact's store, so its own Keychain items outlive a fresh drive

**Status:** Open
**Systems:** native modules (`ExactModuleContext`), `secret.keep` (LLP 1018), agent fresh storage (`EXACT_AGENT_STORAGE_FRESH`), docs
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-10-27

## What happens

The session token is used in Swift (the library's client restores itself from it), so
the module keeps it in its own Keychain item, and the library's store in `context.data`.
`ExactModuleContext` has `data`, `cache` and `temporary`, but no secret store.

A fresh agent drive (`verify ios`) emptied `context.data` but not the module's Keychain
item, and did not tell the module. On the next drive, the module found a session whose
store was gone. A session without its crypto store cannot be used, so the module dropped
it. It could not sign out on the server, so a test device stayed on the account (seen in
the account's device list).

Exact's own secret store (`secret.keep`, then `store.get` and `store.set` in the data
module; `docs/recipes/files-and-grants.md`) clears with a fresh drive. But a native
module cannot reach it, and `docs/recipes/native-module.md` does not mention it, so it was
not found while writing the module.

## What would help

- A secret store on the module's context: get, set and forget a secret that
  `secret.keep` grants, in the same store as the data module's, so it follows `--storage`
  and a fresh drive. Later, an app extension (a notification service extension) needs to
  read it too.
- Or, smaller: a flag on `context` that says the drive started its store empty, so a
  module can clear what it keeps elsewhere.
- One line in `docs/recipes/native-module.md` that points to `secret.keep`.

## Evidence

Seen on 2026-10-27. At `cee509ac82`, `ExactModuleContext`
(`host/apple/modules/ExactNativeModule.swift`) has no secret API, and Exact's only
Keychain code is its own (`host/apple/Sources/ExactKit/Presence.swift`).
````

````markdown
# The editor cannot resolve native module Swift, so every line shows an error

**Status:** Open
**Systems:** native modules, `exact new`, `exact.mjs update`
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-10-27

## What happens

In an editor that uses SourceKit-LSP, every file in `modules/apple/` shows errors such
as `Cannot find type 'ExactModule' in scope`, `Cannot find 'ExactNativeRefusal' in
scope` and `Method does not override any method from its superclass`. These files
compile into one module with `host/apple/modules/ExactNativeModule.swift` and the app's
other Swift, and nothing tells SourceKit that. So the editor gives no useful feedback,
and real errors show only at the next build: 31 s or more with a large module (see
`20261027-module-swift-recompiles-vendor-bindings.md`).

## What would help

`exact new` and `exact.mjs update` writing an editor configuration for `modules/apple/`:
a `buildServer.json` (Build Server Protocol) or a stub `Package.swift` that names the same
sources and Exact's module file.

## Evidence

Seen on 2026-10-27 with exact2 `65577096ed`. No `buildServer` or SourceKit setup is in
`scripts/` or `host/apple/` at `cee509ac82`.
````

````markdown
# `state` prints the value that a password field is bound to

**Status:** Open
**Systems:** agent (`state`, a failed test's notes)
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-10-27

## What happens

`tree`, `layout` and the `type` reply show a `type="password"` field's value as `•••`
(`docs/contract-for-agents.md`, the paragraph on `input type="password"`). The state slot
that the field's `value` reads is printed in clear:

```
"type password not-a-real-secret"  ->  typed #22 "password" … value="•••"
"state password"                   ->  "not-a-real-secret"
```

A drive that signs in with a real password (typed from the Keychain) prints it with any
`state` read that includes the slot, into the agent's output. The docs say that what the
app stores is the app's own, so this is the documented behavior today.

Workaround in the app's AGENTS.md: "do not run `state` before the sign-in ends".

## What would help

`state`, `state --full` and a failed test's notes printing `•••` for a slot that a
`type="password"` field's `value` reads, as `tree` does for the field.

## Evidence

Seen on 2026-10-27 on the iOS simulator.
````

````markdown
# A `role="status"` readout that holds a `progress` is hidden from the iOS bar, with no warning

**Status:** Open
**Systems:** Apple host navigation bar projection, Contract lowering (`lower-header-unplaced`)
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-10-27

## What happens

To show an activity indicator in place of a bar button while a request runs, as UIKit
apps do, the route's header held:

```contract
header display="flex" align-items="center"
  text "Title" role="heading" aria-level=1 flex=1
  if pending(signedIn)
    row role="status" aria-label="Signing in" testId="signing-in"
      progress aria-label="Signing in"
  else
    button press=signIn disabled=(not canSignIn) buttonStyle="filled" testId="sign-in"
      text "Sign In"
```

`contract vocab header` says that a readout (`role="status"`) is a bar item, its custom
view drawn as written. `contract build --json` reported nothing (`[]`). On iOS the bar
showed nothing while the request ran, and `tree` marked both nodes `[not in the iOS bar:
hidden in the app]`. Cost: about 5 minutes. The indicator moved to a section under the
form.

## What would help

Either the readout drawn in the bar, as the vocab says, or a compile warning
(`lower-header-unplaced`) for a readout that the bar cannot hold, naming what it can hold.

## Evidence

Seen at exact2 `65577096ed`. No commit to the navigation bar's code since then, up to
`cee509ac82`.
````

````markdown
# An app whose data comes from an iOS module cannot say that it runs on iOS only

**Status:** Open
**Systems:** `exact.mjs update --without`, authored tests, `verify`
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-10-27

## What happens

All of the app's data comes from its Swift module, so the web build can only show the
first screen. `bun exact.mjs test` on the web fails 2 of 3 tests, which pass on iOS
(`text of "problem" is "<the web fallback's refusal>", expected "<the server's
reason>"`). `update --without` takes `linux` and `android`, not `web`, and a test has no
host line, so `test` and `verify` cannot be told to skip the web.

Workaround in the app's AGENTS.md: "run `test ios` and `verify ios` only".

## What would help

`update --without web` for an app that ships no web build, or a host launch line
(`host ios`) on a test or a test file.

## Evidence

Seen on 2026-10-27 (`bun exact.mjs test`: 1 passed, 2 failed).
````

````markdown
# The native-module recipe leaves out the module's folders, its Swift mode, and how `clock data` treats `later`

**Status:** Open
**Systems:** docs (`docs/recipes/native-module.md`)
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-10-27

## What happens

A module with a slow `later` (a network sign-in of several seconds) needed three facts
that the recipe does not give. Each came from `host/apple/modules/ExactNativeModule.swift`
(77 KB), `host/apple/build.mjs` or a search of the long guides: about 15 minutes in all.

1. `context.data`, `context.cache` and `context.temporary` are the app's own folders,
   and a scratch tree under the agent.
2. Modules compile with `-swift-version 5`, so a `Task { @MainActor in … }` inside
   `later` compiles without Swift 6's strict checks.
3. `clock data` waits for a `native.later` reply in flight. It did, for replies of
   several seconds.

The recipe also does not mention `secret.keep`
(`20261027-native-module-has-no-secret-store.md`) or Exact packages
(`20261027-module-swift-recompiles-vendor-bindings.md`).

## What would help

Three lines in the recipe, and pointers to the two other topics.

## Evidence

The recipe is unchanged between `65577096ed` and `cee509ac82`.
````

````markdown
# `contract vocab` names a tag or a property but not its attributes or values

**Status:** Open
**Systems:** `contract vocab` (`contract/cli`)
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-10-27

## What happens

```
$ bun exact.mjs contract vocab input
input: tag, TextInput (html)
input: handler attribute
  event input
$ bun exact.mjs contract vocab listStyle
listStyle: prop attribute
  prop listStyle, str
```

The attributes that a sign-in field needs (`autocomplete`, `autocapitalize`,
`enterkeyhint`, `inputmode`) came from the tag table in `docs/card.md`. The list styles
(`inset-grouped`, `plain`, or none) came from a table in `docs/contract-for-agents.md`.
Cost: about 5 minutes.

## What would help

`vocab <tag>` printing the tag's line from the card (its attributes and events), and
`vocab <property>` printing the values it accepts.

## Evidence

Seen at exact2 `65577096ed`. The vocab code in `contract/cli/src/main.rs` is unchanged at
`cee509ac82`.
````

````markdown
# `prefer root-font-size` enlarges Exact's text but not native fields or list footers

**Status:** Open
**Systems:** agent (`prefer`), Apple host (iOS), Dynamic Type
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-10-27

## What happens

To see a sign-in form at the largest text size, a drive ran `prefer root-font-size 53`.
The labels grew. The native fields' text and placeholders, and the grouped list's footer,
kept the default size. So the screenshot showed a screen that no device shows, and it
looked broken. The simulator's own setting (`xcrun simctl ui <udid> content_size
accessibility-extra-extra-extra-large`) showed the real screen, which was correct. Cost:
about 3 minutes.

## What would help

A `prefer` key that sets the content size category, so UIKit's text follows too; or the
docs saying that `root-font-size` reaches only the text that Exact draws.

## Evidence

Seen at exact2 `65577096ed` on the iOS simulator.
````

````markdown
# The `chat-thread` recipe's bubble uses `overflow-wrap="anywhere"`, which `verify ios` reports

**Status:** Open
**Systems:** docs (`docs/recipes/chat-thread.md`), `verify`
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-10-27

## What happens

A transcript copied from the recipe (`text m.body … overflow-wrap="anywhere"`) gave one
`verify ios` finding: `breaks app.contract:<line> text overflow-wrap="anywhere": breaks
inside words (Octo/ber); wrap between words (the default) or give the row room`. With
`overflow-wrap="break-word"`, `verify ios` was clean. The recipe's note says that
`anywhere` breaks a long word (a URL) whichever box bounds the bubble, as UIKit does.
Cost: about 2 minutes.

## What would help

The recipe and `verify` agreeing: `break-word` in the recipe, or `verify` accepting
`anywhere` in a bubble with a `max-width`.

## Evidence

Seen on 2026-10-27. The recipe still has `overflow-wrap="anywhere"` at `cee509ac82`.
````

````markdown
# Four agent messages that could say what to do next

**Status:** Open
**Systems:** agent (`scripts/agent.mjs`, `scripts/agent-test.mjs`), `verify`
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-10-27

Each cost 1 or 2 minutes.

1. `reload` in an `agent ios` drive: "reload in an interactive drive supports web; native
   authored tests relaunch their host". Each drive is a new launch, so a second drive
   proves a relaunch. The message could say so.
2. `"screenshot .exact/x.png --scale 3"`: "screenshot: unknown form 3". `--scale` is a
   drive flag. The message could name it.
3. `agent ios "prefer dark"`: the reply listed every accepted key. The step is
   `prefer prefers-color-scheme dark`. A suggestion of the nearest key would save the
   search. (Seen at `65577096ed`.)
4. `verify ios` reported 13 findings (covered, contrast, overlap at the largest text size)
   on a test that ended with an alert open. That follows the rule (a test's end is a
   screen it checks), but no finding said that an alert was up. The fix was to close the
   alert at the end of the test.

## Evidence

The messages in items 1 and 2 are unchanged at `cee509ac82`.
````

````markdown
# An app that uses exact2 by path has no safe way to follow a rewritten `main`

**Status:** Open
**Systems:** `exact.mjs update`, exact2's history, apps outside the repo
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-10-27

## What happens

On 2026-10-27, exact2's `main` history was rewritten twice (a transcript purged on
purpose). Each time, `git pull --ff-only` in the exact2 checkout that the app uses failed:
local `main` and `origin/main` had diverged (the second time, 183 local commits and 209
remote ones). A check of commit subjects showed 177 of the 183 on the remote under new
hashes; the other 6 were the purged transcript and two housekeeping commits. The fix was
a backup branch, then `git reset --hard origin/main`. Cost: about 8 minutes each time.

## What would help

`bun exact.mjs update` (or its help) detecting a rewritten history and saying "back up,
then reset", or a stable tag that apps outside the repo can follow.

## Evidence

From the app's diary entry for the second update. Local backup branches:
`backup/main-before-2026-10-27-rewrite` and `backup/main-before-2026-10-27-rewrite-2`.
````

````markdown
# After `update`, `lock` reports "no changes" for a `Cargo.lock` that `update` just rewrote

**Status:** Open
**Systems:** `exact.mjs update`, `exact.mjs lock`
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-10-27

## What happens

After `bun exact.mjs update`, a command said: "Cargo.lock: does not match the app
manifests; run `bun exact.mjs lock`". `bun exact.mjs lock` then said "current; no
changes", but git showed `Cargo.lock` changed (2 lines). `update` had already written it.
Cost: about 2 minutes.

## What would help

`update` saying that it rewrote the lock, or `lock` not reporting "no changes" for a file
that `update` just changed.

## Evidence

From the app's diary entry for the update to `cee509ac82`.
````
