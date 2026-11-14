surfaces: ios
agent: codex gpt-6.1-sol
task: integrate and verify optional address-book access

### Rough
- a native integration change rebuilt the copied third-party bindings: 110.4 seconds total, including 91.2 seconds in arms and 13.3 seconds in Swift work. separate caching for unchanged vendor bindings would shorten the loop (known finding 1).
- a content search field's magnifier overlapped its value at the real largest native text size. the existing conditional leading-inset workaround fixed it (known finding 64, about 2 minutes to locate and apply). the native field should reserve its icon width at every text size.

### Lean in
- later view-only changes used the new plan on the existing binary without a native rebuild.
- native checks identified an overflowing large-text control and passed after wrapping the header.
- window captures after a short real-clock settling step preserved native controls and materials.

### Needed
- contacts: by hand, existing native store adapter; framework permission purpose provided.

### Checkpoints
- editing app.contract / app.ts: smooth, plan changes reached the native drive.
- iOS build: rough, binding rebuild above.
- driving the app: smooth for settings, permission states, search and account choice; rough for the content search-field inset above.
- native verification: smooth, final run passed 14 tests with clean light/dark and 16 largest-text screens in 250.3 seconds.
