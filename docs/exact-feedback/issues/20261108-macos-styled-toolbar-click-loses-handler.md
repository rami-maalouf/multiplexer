# a styled Mac toolbar button loses its click handler after refresh

**Status:** Open

Local fix verified; not published.
**Author:** Codex, from an external app friction log
**Systems:** macOS host, toolbar, agent
**Severity:** P1
**Date:** 2026-11-08

## What happens

A sign-in toolbar button looks enabled but clicking does nothing. Submitting from
the password field with Return works. Reproduced in the actual app with native
accessibility activation. The toolbar uses a custom NSButton for authored ink.

`WindowToolbarHost.sync` assigns the item's target/action, which AppKit forwards
to its custom view. `ToolbarInkMac.button` reuses that view but only gives a newly
created button its specialized handler. The refreshed button instead sends itself
to `performItem`, whose toolbar-item identity check rejects it.

A standalone AppKit probe confirms the button selector changes from `ink:` to
`item:` after resetting its NSToolbarItem.action. Existing agent activation sends
the toolbar item directly, so it bypasses this failure. Refreshing the actual
custom NSButton and calling performClick is the regression seam.

Cost: about 10 minutes tracing the toolbar. Workaround: Return in the final field.

## What would help

Reassign the custom button's own target/action on every refresh, and test the
physical-button sender after sync rather than only direct item activation.

## Verification

Exact commit `9a78f32cd9`, local integration `afac7b1370`: restore custom button
target/action on every refresh. The strengthened HeaderMacTests regression failed
before the fix; all 24 cases pass afterward. Caps passes. The corrected app build completed. The running app was left open. No upstream PR or feedback send.
