surfaces: ios
agent: codex gpt-6.1-sol
task: show sender profile photos in remote notifications

### Rough
- communication notifications need an intent activity type and signing entitlement, which the app must add in its own post-build extension packager. this extends the existing workaround for missing declarative remote notification support (finding 118).

- the post-build simulator signing step failed: "the entitlements (501 bytes) do not fit exact's section (462 bytes)" when adding communication notifications. the reserved mach-o section is fixed to the framework's original entitlement size, so another needed capability does not fit. the compact simulator plist now omits its redundant version attribute and simulator debugger grant, fitting the required identity, shared storage, push and communication entitlements. device debug entitlements remain unchanged. known finding 118.

### Lean in
- the app keeps message and image fetching in its native core, independently of its view framework.

### Needed
- notifications: by hand; incoming communication intents supply the system sender avatar.

### Checkpoints
- core: three focused avatar-request/response tests and two live plain/encrypted push tests passed.
- native intents: sender identity, image, group context and missing/corrupt image paths passed.
- real notification: first uncached profile photo displayed with the app in background (497 ms, 18 MB), and with the app terminated (452 ms, 18 MB).
- no photo: the message arrived (214 ms, 14 MB); an explicit local initials image was then added because the system otherwise chose the app icon.
- device install: communication-capable provisioning completed; packaged build installed and signed capabilities verified.

- final verification: rebuilt app and all 13 authored ios tests passed; final local initials banner inspected.
