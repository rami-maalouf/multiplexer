# A native button's symbol: the refusal says "sized by font-size", font-size on the button is taken silently, and an image's font-size cannot grow to a cap

**Status:** Open
**Systems:** Contract compiler (lower-button-style), Apple host (native buttons)
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-02

## What happens

A floating bar has a round `buttonStyle="glass"` button whose face is only a symbol. At
the largest accessibility text size the symbol grew past the 48-point circle (UIKit's bar
buttons keep theirs fixed).

1. `font="-exact-title3"` on the `image` was refused: "a native button's `image` takes no
   `font`; ... A native button's face is `text`s and a symbol `image`, sized by
   `font-size`".
2. I read that as `font-size` on the button. The build took `font-size=20` on the button
   with no warning, and the symbol still grew.
3. `font-size=20` on the `image` works (`ButtonConfigurationIOS.swift` reads the symbol's
   own row).

Cost: about 6 minutes and two drives.

Then `verify ios` flagged the fixed size: "`image font-size=20`: stays 20 pt as Dynamic Type
grows; a role (`font="-exact-title1"`) or a `rem` size ("1.25rem") scales". A role made the
symbol overflow its 48-point glass circle again, so the app wanted a size that grows to a cap.
`font-size="min(1.2rem, 24px)"` on the image is refused ("expected number"), though the same
`min()` works on a `text`, and `exactPage()` answers no root font size. The app now picks 20
or 24 from `exactViewport().accessibilityTextSize`. Another 10 minutes.

## What would help

- The refusal saying "write `font-size` on the image".
- A warning for `font-size` on a native button whose face has no `text`.
- An image's `font-size` taking the `rem` and `min()` forms a `text` takes, so a symbol in a
  fixed control can grow with the text size to a cap; and the fixed-type finding naming that
  form.

## Evidence

Seen on 2026-11-02 at exact2 `ed43ad09a0`, iOS Simulator (iOS 26.5).

Seen again on 2026-11-02 at `ed43ad09a0`, in a bottom sheet's rows (a symbol in a fixed box
beside network logos): `verify ios` flagged `image ... font-size=(largeText ? 30 : 22)` as
fixed type ("stays 30 pt as Dynamic Type grows"), while the same app's bar writes
`derive symbolSize = largeText ? 24 : 20` and `font-size=symbolSize`, which it does not flag.
Both grow the same way at the accessibility sizes. With the sizes in a `derive`, `verify` was
clean. So the fixed-type check treats two equal forms differently, and still names no capped
form it accepts. About 2 minutes.
