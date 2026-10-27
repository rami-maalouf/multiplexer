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
