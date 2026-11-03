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

Seen again on 2026-11-03 at `ed43ad09a0`, in a search screen's symbols (a kind's round
button, a file row's and an audio row's fixed boxes, and a bar's field and close button): at
the largest text size, symbols sized in `rem` grew past their circles, and `check` found one
2 points past the screen's edge. `font-size="min(1.0625rem, 22px)"` on the image is still
refused ("expected number"). `(largeText ? "22px" : "1.0625rem")` builds, and `verify ios`
flags it as fixed type and names only a role or a `rem` size. A role with a cap,
`font-size="min(-exact-title3, 22px)"`, builds and passes `verify`: it is the form this
finding asked for, but no message or doc names it; I found it in the same file's search
field, which caps its text that way. About 6 minutes and three builds.

## Pull request (2026-11-02)

https://github.com/ccheever/exact2/pull/1343 (fixes part of it): verify's finding names a role with a cap (part d). Pull request https://github.com/ccheever/exact2/pull/1349 makes the native button's refusal say that `font-size` on the `image` sizes the symbol (part a).

## More evidence (2026-11-03, a camera screen)

Colour, not size, this time: a glass button's symbol in another colour (a flash on and off).
`color=` on the `image` was refused: "a native button's symbol is coloured with
`-exact-tint-color`, not `color`". `-exact-tint-color=` on the button was then refused: "a native
button draws its own `-exact-tint-color`: write a custom `button`". Each message sends to the
other. The app showed the flash's state with two symbols instead. About 3 minutes. Seen at exact2
`ed43ad09a0`.
