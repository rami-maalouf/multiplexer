# A reactive root accent leaves a prominent native header blue

**Status:** Open
**Systems:** iOS window tint, navigation root, prominent header items
**Severity:** P2
**Author:** local app feedback (original agent not recorded)
**Date:** 2026-11-04
**Finding:** 125

Local state: local only; native failure observed, source hypothesis under test.

## Observed behavior

A navigation root authors a reactive `accent-color`. Choosing yellow updates its
caret and an in-route send control, but an enabled prominent native header action
stays blue. Mounted yellow/orange changes and a cold persisted palette were
observed. The native accessibility tree identifies the header action as a control.
An ordinary app verification pass does not detect this visual mismatch.

The appearance lane retains `.exact/appearance/header-after-yellow-change.png`
(a DISPLAY capture), `header-native-tree.log`, and `header-repro.md` with cold,
mounted-change and reset steps. `header-after-orange-change.png` and
`header-cold-yellow.png` are APP fallbacks: they are not evidence of backdrop
sampling or blur contrast. `PROOF.md`, `proof.json` and `capture-provenance.json`
retain the full receipt. App feature head `dbff982` plus tested contrast follow-up
`01b070d7bba5927f5cd2d7b168758264caf6dcf9` uses framework `ed43ad09a0`.
Expected tint must come from the current palette function, not an earlier copied
value. The contrast follow-up does not change the palette interface.

## Source hypothesis, not yet a runtime regression result

`AppAccent.restyled` checks `node.superview === presenter.root`. Navigation can
move the logical root into a route controller, so later root restyles no longer
reach window tint through that check. Descendants can still read authored tint.
The hypothesis is that accent ownership must follow logical root identity across
physical reparenting, without allowing old retained roots to retake the window.

An isolated test-only branch from `7529006ab992ff021f790291fedd05b189250e81`
adds late-load, mounted-change, reset and retained-old-root controls. Its production
tint source is unchanged. Build-for-testing succeeded; runtime RED is pending an
explicit simulator slot. This is setup readiness, not a failed regression result.
Executable SHA-256: `63f86ca65f056d065f70396172906267753338d78972007da0c43cecaa32bbc6`.
Build log: `/tmp/mx-tint-red-build.log`.

## Separate foreground requirement

A prominent item's window tint controls its fill. `NavigationBarIOS.configure`
currently excludes authored text color from prominent-item tint assignment.
Fixing window propagation does not establish the label foreground is correct.
Dark yellow/white fills need their authored contrasting foreground verified,
along with cold load, mounted changes, reset and header reconstruction. No app
window-tint bridge or production framework patch is included yet.

All feedback stays local; nothing published.
