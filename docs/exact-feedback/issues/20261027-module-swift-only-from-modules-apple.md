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
