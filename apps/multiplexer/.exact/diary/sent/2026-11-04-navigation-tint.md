surfaces: ios
task: reactive navigation-root tint and prominent header foreground

### Rough
- a prominent native header remains blue while a reactive root palette updates the caret and in-route controls. Verification was clean despite the visible mismatch. Source inspection found a physical-superview guard in AppAccent and separate prominent-item foreground behavior in NavigationBarIOS. A regression covering logical root reparenting would have caught the likely propagation gap.

### Lean in
- reuse the appearance lane's display capture and provenance, retaining app-fallback limits.
- isolate this investigation from the validated row-cancellation checkout used by another lane.

### Needed
- a runtime baseline for late accent load after reparenting, mounted changes, reset and old retained roots
- independent native proof of prominent foreground, not just window fill

### Checkpoints
- local finding 125 allocated by coordinator; no publication.
- exact2-navigation stays clean at 7529006ab992ff021f790291fedd05b189250e81.
- exact2-tint / local/navigation-root-tint contains two new AppAccent regression tests only; production source unchanged.
- off-simulator build-for-testing succeeded, /tmp/mx-tint-red-build.log. Test executable SHA-256 63f86ca65f056d065f70396172906267753338d78972007da0c43cecaa32bbc6. Runtime red not run; no auth or core lock, own simulator off.
